module Ex4Edit where  -- this exercise is worth 25 marks

{- This is the file where you should work. -}

{- You can compile this file by issuing the command
     make Ex4Edit
   in a shell, provided you are in the "exercises" directory.
   You can then run the editor by issuing the command
     ./Ex4Edit
   and you should find that it is in "working" order, even
   though there are lots of bits missing, and what's there
   has obvious bugs in it.
-}

open import CS410-Prelude
open import CS410-Nat
open import Ex4AgdaSetup

  -- the setup gives you a nondependent pair type _**_
  -- because that's what the compiler can exchange with Haskell code

{- The key editor data structure is the cursor. A Cursor M X represents
   being somewhere in the middle of a sequence of X values, holding an M. -}

data BV (X : Set) : Nat -> Set where
  [] : BV X zero
  _<:_ : forall {n} -> BV X n -> X -> BV X (suc n)

record Cursor (M X : Set) : Set where
  constructor _!_<[_]>_
  field
    position  : Nat              -- you know how far "in" you are
    beforeMe  : BV X position    -- and there is that much stuff before you
    atMe      : M
    afterMe   : List X           -- but any amount of stuff after you
infix 2 _!_<[_]>_

{- An editor buffer is a nested cursor: we're in the middle of a bunch of
   *lines*, holding a cursor for the current line, which puts us in the
   middle of a bunch of characters, holding the element of One. -}
Buffer : Set
Buffer = Cursor (Cursor One Char) (List Char)
{- Note that the "position"s in the  buffer gives you the y and x coordinates
   of the cursor! -}

{- This operator, called "chips", shuffles the elements from a backward list
   on to the start of a forward list, keeping them in the same order. -}
_<>>_ : {X : Set}{n : Nat} -> BV X n -> List X -> List X
[]         <>> xs  = xs
(xz <: x)  <>> xs  = xz <>> (x :: xs)

{- The "fish" operator goes the other way, giving you the length. -}
_<><_ : {X : Set}{n : Nat} -> BV X n -> List X -> Sg Nat \ m -> BV X m
xz <>< []         = _ , xz
xz <>< (x :: xs)  = (xz <: x) <>< xs

{- You can turn a buffer into a list of lines, preserving its text. -}
bufText : Buffer -> List (List Char)
bufText
  (_ ! sz <[
   _ ! cz <[ <> ]> cs
   ]> ss)
  = sz <>> ((cz <>> cs) :: ss)

{- Here's an example of a proof of a fact about fish and chips. -}
firstFishFact : {X : Set}{n : Nat} -> (xz : BV X n)(xs : List X) ->
  snd (xz <>< xs) <>> []  ==  xz <>> xs
firstFishFact xz []          = refl
firstFishFact xz (x :: xs)   = firstFishFact (xz <: x) xs

{- You will need more such facts. -}

{- EXERCISE 4.1 -}
{- When we start the editor with the command
      ./Ex4Edit foo.txt
   the contents of foo.txt will be turned into a list of lines.
   Your (not so tricky) mission is to turn the file contents into a buffer which
   contains the same text.
   (1 mark)
-}
initBuf : List (List Char) -> Buffer
initBuf ss =
  0 ! [] <[
  0 ! [] <[ <> ]> []
  ]> []


{- As you can see, the current version will run, but it always gives the empty
   buffer, which is not what we want unless the input is empty. -}

{- Next comes the heart of the editor. You get a keystroke and the current buffer,
   and you have to say what is the new buffer. You also have to say what is the
   extent of the change.

   The tricky part is this: you have to be honest enough about your change
   report, so that we don't underestimate the amount of updating the screen needs.
-}

Honest : Buffer -> Change ** Buffer -> Set
Honest b (allQuiet    , b')  = b == b'
Honest b (cursorMove  , b')  = bufText b == bufText b'
Honest (n ! sz <[ _ ]> ss) (lineEdit , (n' ! sz' <[ _ ]> ss'))
  = (_==_ {_}{Sg Nat (BV (List Char))} (n , sz) (n' , sz')) ** (ss == ss')
Honest _ (bigChange   , _)
  = One

record UpdateFrom (b : Buffer) : Set where   -- b is the starting buffer
  constructor _///_
  field
    update  : Change ** Buffer   -- change and new buffer
    honest  : Honest b update
open UpdateFrom
infix 2 _///_


{- EXERCISE 4.2 -}
{- Implement the appropriate behaviour for as many keystrokes as you can.
   I have done a couple for you, but I don't promise to have done them
   correctly. -}
keystroke : Key -> (b : Buffer) -> UpdateFrom b
keystroke (char c)
  (y ! sz <[
   x ! cz <[ <> ]> cs
   ]> ss)
  = lineEdit ,
  (y ! sz <[
   x ! cz <[ <> ]> c :: cs
   ]> ss)
  /// refl , refl          -- see? same above and below
keystroke (arrow normal right)
  (suc y ! sz <: s <[
   zero ! [] <[ <> ]> cs
   ]> ss)
  = cursorMove ,
  (y ! sz <[ _ ! snd ([] <>< s) <[ <> ]> [] ]> cs :: ss)
  /// within (\ HOLE -> sz <>> (HOLE :: cs :: ss)) turn s into snd ([] <>< s) <>> []
        because sym (firstFishFact [] s)
keystroke k b = allQuiet , b /// refl
{- Please expect to need to invent extra functions. -}
{- Remember also that you can always overestimate the change by saying bigChange,
   which needs only a trivial proof. But you may find that the display will flicker
   badly if you do. -}
{- (char c)                 1 mark
   enter                    2 marks
   backspace delete         3 marks for the pair
   left right               4 marks for the pair (with cursorMove change)
   up down                  4 marks for the pair (with cursorMove change)
   -}


{- EXERCISE 4.3 -}
{- You will need to improve substantially on my implementation of the next component,
   whose purpose is to update the window. Mine displays only one line! -}
render :
  Nat ** Nat ->        -- height and width of window -- CORRECTION! width and height
  Nat ** Nat ->        -- first visible row, first visible column
  Change ** Buffer ->  -- what just happened
  List Action **       -- how to update screen
    (Nat ** Nat)       -- new first visible row, first visible column
render _ tl (allQuiet , _) = ([] , tl)
render _ tl (_ , (_ ! _ <[ _ ! cz <[ <> ]> cs ]> _))
  = (goRowCol 0 0 :: sendText (cz <>> cs) :: []) , tl
{- The editor window gives you a resizable rectangular viewport onto the editor buffer.
   You get told
     the current size of the viewport
     which row and col of the buffer are at the top left of the viewport
       (so you can handle documents which are taller or wider than the window)
     the most recent change report and buffer

   You need to figure out whether you need to move the viewport
       (by finding out if the cursor is still within the viewport)
     and if so, where to. Remember, you know where the cursor is!

   You need to figure out what to redisplay. If the change report says
     lineEdit and the viewport has not moved, you need only repaint the
     current line. If the viewport has moved or the change report says
     bigChange, you need to repaint the whole buffer.

   You will need to be able to grab a rectangular region of text from the
     buffer, but you do know how big and where from.

   Remember to put the cursor in the right place, relative to where in
     the buffer the viewport is supposed to be. The goRowCol action takes
     *viewport* coordinates, not *buffer* coordinates! You will need to
     invent subtraction!
-}
{- Your code does not need to worry about resizing the window. My code does
   that. On detecting a size change, my code just calls your code with a
   bigChange report and the same buffer, so if you are doing a proper repaint,
   the right thing will happen. -}
{- 3 marks for ensuring that a buffer smaller than the viewport displays
       correctly, with the cursor in the right place, if nobody changes
       the viewport size
   2 marks for ensuring that the cursor remains within the viewport even if
       the viewport needs to move
   1 mark for ensuring that lineEdit changes need only affect one line of
       the display (provided the cursor stays in the viewport)
-}

{- Your code then hooks into mine to produce a top level executable! -}
main : IO One
main = mainLoop initBuf (\ k b -> update (keystroke k b)) render

{- To build the editor, just do
     make Ex4Edit
   in a shell window.
   To run the editor, once compiled, do
     ./Ex4Edit
   in the shell window, which should become the editor window.
   To quit the editor, do
     ctrl-C
   like an old-fashioned soul.
-}


{- EXERCISE 4.4 -}
{- For the last 4 marks, do something interesting!
   You can score 2 marks by adding more exciting cursor moves, e.g.,
   beginning/end of line/buffer, or jumping around a word at a time.
   For all 4 marks, do something that requires you to change the representation
   of the buffer, e.g.,
     * making up and down remember what column you were in, even if you pass
         through lines which are shorter (so the buffer needs to remember if
         you are in "up-and-down mode", and if so, what the target column is;
     * selection and cut-copy-paste: you will need some way to remember if you
         are currently making a selection (with shifted arrow keys), and if so,
         where the selection starts; you will also need to remember the clipboard
   (4 marks)
 -}


{- There is no one right way to do this exercise, and there is some scope for
   extension. It's important that you get in touch if you need help, either in
   achieving the basic deliverable, or in finding ways to explore beyond it.
-}
