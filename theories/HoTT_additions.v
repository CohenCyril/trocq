(*****************************************************************************)
(*                            *                    Trocq                     *)
(*  _______                   *           Copyright (C) 2023 MERCE           *)
(* |__   __|                  *    (Mitsubishi Electric R&D Centre Europe)   *)
(*    | |_ __ ___   ___ __ _  *       Cyril Cohen <cyril.cohen@inria.fr>     *)
(*    | | '__/ _ \ / __/ _` | *       Enzo Crance <enzo.crance@inria.fr>     *)
(*    | | | | (_) | (_| (_| | *   Assia Mahboubi <assia.mahboubi@inria.fr>   *)
(*    |_|_|  \___/ \___\__, | ************************************************)
(*                        | | * This file is distributed under the terms of  *)
(*                        |_| * GNU Lesser General Public License Version 3  *)
(*                            * see LICENSE file for the text of the license *)
(*****************************************************************************)

From Coq Require Import ssreflect.
From HoTT Require Export HoTT.

Set Universe Polymorphism.
Unset Universe Minimization ToSet.

Definition equiv_forall_sigma {A : Type} {P : A -> Type} {Q : forall a, P a -> Type} :
  (forall a (b : P a), Q a b) <~> forall x : { a : A | P a }, Q x.1 x.2.
Proof.
unshelve econstructor. { move=> f [a b]; exact (f a b). }
unshelve econstructor. { move=> g a b; exact (g (a; b)). }
all: constructor.
Defined.

Lemma equiv_invK {A B} (e : A <~> B) x : e (e^-1%equiv x) = x.
Proof. by case: e => [f []]. Defined.

Lemma equiv_funK {A B} (e : A <~> B) x : e^-1%equiv (e x) = x.
Proof. by case: e => [f []]. Defined.

Definition IsFun {A B : Type@{i}} (R : A -> B -> Type@{i}) :=
  (forall x, Contr {y | R x y}).

Fact isfun_isprop `{Funext} {A B : Type@{i}} (R : A -> B -> Type@{i}) :
  IsHProp (IsFun R).
Proof. typeclasses eauto. Defined.

Lemma fun_isfun {A B : Type@{i}} (f : A -> B) : IsFun (fun x y => f x = y).
Proof. by move=> x; eexists (f x; 1%path) => -[y]; elim. Defined.

Definition sym_rel@{i} {A B : Type@{i}} (R : A -> B -> Type@{i}) := fun b a => R a b.

Lemma isequiv_isfun `{Univalence} {A B : Type@{i}} (f : A -> B) :
  IsEquiv f <~> IsFun (fun x y => f y = x).
Proof. by symmetry; apply equiv_contr_map_isequiv. Defined.

Lemma type_equiv_contr `{Univalence} {A : Type@{i}} :
  A <~> {P : A -> Type | Contr {x : A & P x}}.
Proof.
apply equiv_inverse; unshelve eapply equiv_adjointify.
- move=> [F [[a ?] ?]]; exact a.
- by move=> a; exists (paths a); apply contr_basedpaths.
- done.
- move=> [P Pc]; unshelve eapply path_sigma. {
    apply: path_arrow => a; apply: equiv_path_universe.
    apply: equiv_inverse; apply: equiv_path_from_contr.
    by case: Pc => -[]. }
  by apply: path_contr.
Defined.

Lemma fun_equiv_isfun `{Univalence} {A B : Type} :
  (A -> B) <~> {R : A -> B -> Type | IsFun R}.
Proof.
have fe : Funext by apply: Univalence_implies_Funext.
transitivity (A -> {P : B -> Type | Contr {y : B & P y}}).
  { apply: equiv_postcompose'; exact type_equiv_contr. }
by apply (equiv_composeR' (equiv_sig_coind _ _)^-1).
Defined.

Lemma equiv_sig_relequiv `{Univalence} {A B : Type@{i}} :
  (A <~> B) <~> RelEquiv A B.
Proof.
apply (equiv_composeR' (issig_equiv _ _)^-1).
apply (equiv_compose' issig_relequiv).
apply (equiv_compose' (equiv_sigma_assoc' _ _)^-1).
unshelve eapply equiv_functor_sigma.
- exact: fun_equiv_isfun.
- by move=> f; apply: isequiv_isfun.
- exact: equiv_isequiv.
- by move=> f; apply: equiv_isequiv.
Defined.

Definition apD10_path_forall_cancel `{Funext} :
  forall {A : Type} {B : A -> Type} {f g : forall x : A, B x} (p : forall x, f x = g x),
    apD10 (path_forall f g p) = p.
Proof.
  intros. unfold path_forall.
  apply moveR_equiv_M.
  reflexivity.
Defined.

Definition transport_apD10 :
  forall {A : Type} {B : A -> Type} {a : A} (P : B a -> Type)
         {t1 t2 : forall x : A, B x} {e : t1 = t2} {p : P (t1 a)},
    transport (fun (t : forall x : A, B x) => P (t a)) e p =
    transport (fun (t : B a) => P t) (apD10 e a) p.
Proof.
  intros A B a P t1 t2 [] p; reflexivity.
Defined.

Definition coe_inverse_cancel {A B} (e : A = B) p: coe e (coe e^ p) = p.
Proof. elim: e p; reflexivity. Defined.

Definition coe_inverse_cancel' {A B} (e : A = B) p :  coe e^ (coe e p) = p.
Proof. elim: e p; reflexivity. Defined.

Definition path_forall_types `{Funext} A F G :
  (forall (a : A), F a = G a) -> (forall a, F a) = (forall a, G a).
Proof. by move=> /(path_forall _ _)->. Defined.

Definition equiv_flip@{i k | i <= k} :
	forall (A B : Type@{i}) (P : A -> B -> Type@{k}),
    Equiv@{k k} (forall (a : A) (b : B), P a b) (forall (b : B) (a : A), P a b).
Proof.
  intros A B P.
  unshelve eapply Build_Equiv@{k k}.
  - exact (@flip@{i i k} A B P).
  - by unshelve eapply
      (@Build_IsEquiv@{k k}
        (forall (a : A) (b : B), P a b) (forall (b : B) (a : A), P a b)
        (@flip@{i i k} A B P)
        (@flip@{i i k} B A (fun (b : B) (a : A) => P a b))).
Defined.
