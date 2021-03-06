module Ex3 where

open import CS410-Prelude
open import CS410-Nat
open import CS410-Indexed


----------------------------------------------------------------------------
-- FUN WITH INDEXED SETS, FUNCTORS AND MONADS
----------------------------------------------------------------------------


-- EPISODE 1
-- FIRST-ORDER TYPED SYNTAX

-- Remember "Typed Hutton's Razor"? Let's add typed variables!

data Ty : Set where nat bool : Ty

data TH (X : Ty -> Set)  -- X t is the set of free variables of type t
        : Ty -> Set where
  var : forall {t} -> X t -> TH X t  -- variables are terms of their own type
  -- and the rest is as before
  val : Nat -> TH X nat
  boo : Two -> TH X bool
  add : TH X nat -> TH X nat -> TH X nat
  ifte : forall {t} -> TH X bool -> TH X t -> TH X t -> TH X t  

-- ???
-- 3.1 Implement the MonadIx which equips this typed syntax with
-- type-safe simultaneous substitution (replacing all the variables at once)

THMonadIx : MonadIx TH
THMonadIx = record { retIx = var ; extendIx = {!!} }

-- ???
-- 3.2 Prove that the MonadIxLaws hold for your implementation.

THMonadIxLaws : MonadIxLaws THMonadIx
THMonadIxLaws = record { lunit = {!!} ; runit = {!!} ; assoc = {!!} }

-- ???
-- 3.3 Implement an interpreter for typed Hutton's razor which uses an
-- *environment* to give values to the variables.

Val : Ty -> Set
Val nat  = Nat
Val bool = Two

eval : forall {X} -> [ X -:> Val ] -> [ TH X -:> Val ]
eval g t = {!!}

-- ???
-- 3.4 Prove that evaluation respects substitution.

module EVALSUB where
  open MonadIx THMonadIx
  open MonadIxLaws THMonadIxLaws
  evalSub : forall {X Y}(sb : [ X -:> TH Y ])(g : [ Y -:> Val ]){ty}(t : TH X ty) ->
            eval g (extendIx sb t) == eval (\ x -> eval g (sb x)) t
  evalSub sb g t = {!!}


-- EPISODE 2
-- Interaction structures and session protocols

-- ???
-- 3.5 Show that for any interaction structure C : I => I,
-- FreeIx C obeys the MonadIxLaws
-- HINT: you will need to make use of "EXT".

module FREEIXLAWS {I : Set}(C : I => I) where
  open MonadIx (freeMonadIx C)
  
  rhelp : forall {X}{i}(fcx : FreeIx C X i) ->
          extendIx retIx fcx == fcx
  rhelp (ret x) = refl
  rhelp (do (c , k)) rewrite EXT (λ r → extendIx retIx (k r)) k (\ r -> rhelp (k r)) = refl

  freeMonadIxLaws : MonadIxLaws (freeMonadIx C)
  freeMonadIxLaws = record { lunit = {!!} ; runit = \ f p -> rhelp (f p) ; assoc = {!!} }

-- PROTOCOLS

So : Two -> Set
So tt = One
So ff = Zero

data Protocol : Set where
  stop : Protocol  -- communication ends
  send recv :     (chk : Char -> Two)  -- a test of character
              ->  ((c : Char) -> So (chk c) -> Protocol)
                     -- how to continue after sending/receiving an acceptable character
              -> Protocol

-- ???
-- 3.6 Construct an interaction structure which describes how to perform one step
-- of a protocol. That is, the possible commands and responses should capture the
-- information exchanged in just the first communication action that the protocol
-- allows (does "stop" allow any communication actions?); the next function should
-- compute what the rest of the protocol is. The idea is that FreeIx Comms should
-- capture exactly the strategies for valid communications according to the
-- protocol.

Comms : Protocol => Protocol
Comms = {!!} <! {!!} / {!!}

-- ???
-- 3.7 Given a protocol, show how to construct the "dual" protocol, in which the
-- roles of send and recv have been swapped.

dual : Protocol -> Protocol
dual p = {!!}

-- Signal *traffic* is a list of pairs of bits and characters,
-- recording which data were exchanged

Traffic = List ( Two   -- tt for "sent", ff for "received"
               * Char  -- what was sent or received
               )

-- ???
-- 3.8 Define a type which accurately represents the evidence that some
-- traffic is valid for a given protocol.

Valid : Protocol -> Traffic -> Set
Valid p bcs = {!!}

-- ???
-- 3.9 Show that if traffic is valid for a protocol, flipping the bits in the
-- traffic gives valid traffic for the dual protocol.

mapList : forall {S T} -> (S -> T) -> List S -> List T
mapList f []         = []
mapList f (x :: xs)  = f x :: mapList f xs

not : Two -> Two
not tt = ff
not ff = tt

dualValid : (p : Protocol)(bcs : Traffic) ->
            Valid p bcs -> Valid (dual p) (mapList (\ { (b , c) -> not b , c }) bcs)
dualValid p bcs v = {!!}

-- ???
-- 3.10 Show that any two strategies for interacting according to a protocol and its
-- dual, respectively, can be successfully coroutined to generate valid traffic for the
-- protocol.

communicate : (p : Protocol)
              (me  : FreeIx Comms (_==_ stop) p)
              (you : FreeIx Comms (_==_ stop) (dual p)) ->
              Sg Traffic \ bcs -> Valid p bcs
communicate p me you = {!!}


-- ???
-- 3.11 Implement an example protocol (for a binary arithmetic server)
-- Here is the spec:
--   Client sends a single decimal digit, n.
--   Client sends a sequence of binary digits exactly 2^n bits long.
--   Client sends either '+' or '-'.
--   Client sends another sequence of binary digits exactly 2^n bits long.
--   Server responds with a sequence of binary digits exactly 2^n bits long,
--     which is the sum or difference (as indicated) of the other two.

binaryClientProtocol : Protocol
binaryClientProtocol = {!!}

  -- you will need to implement a bunch of helpers to check validity, e.g.,

isBit : Char -> Two
isBit '0' = tt
isBit '1' = tt
isBit _   = ff

  -- you will also need to interpret things which pass the check

whichBit : (c : Char) -> So (isBit c) -> Two
whichBit '0' p = ff
whichBit '1' p = tt
whichBit _ p = ff  -- frustratingly, a dummy is needed here
                   -- but you still can't give a wrong bit

  -- you might also want to use the following representation of bit sequences

Word : Nat -> Set
Word zero = Two
Word (suc n) = Word n * Word n

  -- here's an example of an arithmetic operation

wordAddBit : (n : Nat) -> Word n -> Two -> Two * Word n
wordAddBit n w ff = ff , w
wordAddBit zero tt tt = tt , ff
wordAddBit zero ff tt = ff , tt
wordAddBit (suc n) (hi , lo) b with wordAddBit n lo b
wordAddBit (suc n) (hi , lo) b | c , lo' with wordAddBit n hi c
wordAddBit (suc n) (hi , lo) b | c , lo' | d , hi' = d , hi' , lo'

zeroWord : (n : Nat) -> Word n
zeroWord zero = ff
zeroWord (suc n) = z , z where z = zeroWord n

-- a really bad way to convert unary to binary

nat2Word : (n : Nat) -> Nat -> Word n
nat2Word n zero = zeroWord n
nat2Word n (suc x) = snd (wordAddBit n (nat2Word n x) tt)

example : Word 3
example = nat2Word 3 42


-- Now implement a client and server

binaryClient : FreeIx Comms (_==_ stop) binaryClientProtocol
binaryClient = {!!}

binaryServer : FreeIx Comms (_==_ stop) (dual binaryClientProtocol)
binaryServer = {!!}

-- Make them communicate!

