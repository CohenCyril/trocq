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
From HoTT Require Import HoTT.
Require Import HoTT_additions Database.
From elpi Require Import elpi.

From Trocq.Elpi Extra Dependency "param-class.elpi" as param_class.

Set Universe Polymorphism.
Unset Universe Minimization ToSet.

Set Polymorphic Inductive Cumulativity.

(*************************)
(* Parametricity Classes *)
(*************************)

Module Map0.
Record Has@{i} {A B : Type@{i}} (R : A -> B -> Type@{i}) := BuildHas {}.
End Map0.

Module Map1.
Record Has@{i} {A B : Type@{i}} (R : A -> B -> Type@{i}) := BuildHas {
  map : A -> B
}.
End Map1.

Module Map2a.
Record Has@{i} {A B : Type@{i}} (R : A -> B -> Type@{i}) := BuildHas {
  map : A -> B;
  map_in_R : forall (a : A) (b : B), map a = b -> R a b
}.
End Map2a.

Module Map2b.
Record Has@{i} {A B : Type@{i}} (R : A -> B -> Type@{i}) := BuildHas {
  map : A -> B;
  R_in_map : forall (a : A) (b : B), R a b -> map a = b
}.
End Map2b.

Module Map3.
Record Has@{i} {A B : Type@{i}} (R : A -> B -> Type@{i}) := BuildHas {
  map : A -> B;
  map_in_R : forall (a : A) (b : B), map a = b -> R a b;
  R_in_map : forall (a : A) (b : B), R a b -> map a = b
}.
End Map3.

Module Map4.
(* An alternative presentation of Sozeau, Tabareau, Tanter's univalent parametricity:
   symmetrical and transport-free *)
Record Has@{i} {A B : Type@{i}} (R : A -> B -> Type@{i}) := BuildHas {
  map : A -> B;
  map_in_R : forall (a : A) (b : B), map a = b -> R a b;
  R_in_map : forall (a : A) (b : B), R a b -> map a = b;
  R_in_mapK : forall (a : A) (b : B) (r : R a b), (map_in_R a b (R_in_map a b r)) = r
}.
End Map4.

(********************)
(* Record Hierarchy *)
(********************)

Elpi Command genhierarchy.
Elpi Accumulate Db trocq.db.
Elpi Accumulate File param_class.
Elpi Accumulate lp:{{
  % generate a module with a record type containing:
  % - a relation R : A -> B -> Type;
  % - a covariant (A to B) instance of one of the classes of Map listed above;
  % - a contravariant (B to A) instance.
  % (projections are generated so that all fields are accessible from the top record)
  pred generate-module i:param-class, i:univ, i:univ.variable.
  generate-module (pc M N as Class) U L :-
    map-class->string M MStr,
    map-class->string N NStr,
    % open module
    coq.env.begin-module {calc ("Param" ^ MStr ^ NStr)} none,
    % generate record
    coq.univ-instance UI [L],
    coq.locate {calc ("Map" ^ MStr ^ ".Has")} CovariantSubRecord,
    coq.locate {calc ("Map" ^ NStr ^ ".Has")} ContravariantSubRecord,
    coq.locate "sym_rel" SymRel,
    RelDecl =
      parameter "A" _ (sort (typ U)) (a\
        parameter "B" _ (sort (typ U)) (b\
          record "Rel" (sort (typ {coq.univ.super U})) "BuildRel" (
            field [] "R" {{ lp:a -> lp:b -> lp:{{ sort (typ U) }} }} (r\
            field [] "covariant" (app [pglobal CovariantSubRecord UI, a, b, r]) (_\
            field [] "contravariant"
              (app [pglobal ContravariantSubRecord UI, b, a, app [pglobal SymRel UI, a, b, r]]) (_\
          end-record)))))),
    @primitive! => @udecl! [L] ff [] ff => coq.env.add-indt RelDecl TrocqInd,
    coq.locate "Rel" Rel,
    coq.locate "R" R,
    % add R to database for later use
    R = const CR,
    coq.elpi.accumulate _ "trocq.db"
      (clause _ (after "default-r") (trocq.db.r Class CR)),
    coq.elpi.accumulate execution-site "trocq.db"
      (clause _ _ (trocq.db.gref->class (indt TrocqInd) Class)),
    % generate projections on the covariant subrecord
    map-class->fields M MFields,
    coq.locate "covariant" Covariant,
    std.forall MFields (field\ sigma FieldName Field Decl\
      FieldName is "Map" ^ MStr ^ "." ^ field,
      coq.locate FieldName Field,
      Decl =
        (fun `A` (sort (typ U)) a\ fun `B` (sort (typ U)) b\ fun `P` (app [pglobal Rel UI, a, b]) p\
          app [pglobal Field UI, a, b,
            app [pglobal R UI, a, b, p], app [pglobal Covariant UI, a, b, p]]),
      @udecl! [L] ff [] ff => coq.env.add-const field Decl _ @transparent! _
    ),
    % generate projections on the contravariant subrecord
    map-class->fields N NFields,
    map-class->cofields N NCoFields,
    coq.locate "contravariant" Contravariant,
    std.forall2 NFields NCoFields (field\ field-name\ sigma FieldName Field Decl\
      FieldName is "Map" ^ NStr ^ "." ^ field,
      coq.locate FieldName Field,
      Decl =
        (fun `A` (sort (typ U)) a\ fun `B` (sort (typ U)) b\
          fun `P` (app [pglobal Rel UI, a, b]) p\
            app [pglobal Field UI, b, a,
              app [pglobal SymRel UI, a, b, app [pglobal R UI, a, b, p]],
              app [pglobal Contravariant UI, a, b, p]]),
      @udecl! [L] ff [] ff => coq.env.add-const field-name Decl _ @transparent! _
    ),
    % close module
    coq.env.end-module _.
}}.
Elpi Typecheck.

(********************)
(* Record Weakening *)
(********************)

Definition forgetMap43@{i}
  {A B : Type@{i}} {R : A -> B -> Type@{i}} (m : Map4.Has@{i} R) : Map3.Has@{i} R :=
    @Map3.BuildHas A B R (@Map4.map A B R m) (@Map4.map_in_R A B R m) (@Map4.R_in_map A B R m).

Definition forgetMap32a@{i}
  {A B : Type@{i}} {R : A -> B -> Type@{i}} (m : Map3.Has@{i} R) : Map2a.Has@{i} R :=
    @Map2a.BuildHas A B R (@Map3.map A B R m) (@Map3.map_in_R A B R m).

Definition forgetMap32b@{i}
  {A B : Type@{i}} {R : A -> B -> Type@{i}} (m : Map3.Has@{i} R) : Map2b.Has@{i} R :=
    @Map2b.BuildHas A B R (@Map3.map A B R m) (@Map3.R_in_map A B R m).

Definition forgetMap2a1@{i}
  {A B : Type@{i}} {R : A -> B -> Type@{i}} (m : Map2a.Has@{i} R) : Map1.Has@{i} R :=
    @Map1.BuildHas A B R (@Map2a.map A B R m).

Definition forgetMap2b1@{i}
  {A B : Type@{i}} {R : A -> B -> Type@{i}} (m : Map2b.Has@{i} R) : Map1.Has@{i} R :=
    @Map1.BuildHas A B R (@Map2b.map A B R m).

Definition forgetMap10@{i}
  {A B : Type@{i}} {R : A -> B -> Type@{i}} (m : Map1.Has@{i} R) : Map0.Has@{i} R :=
    @Map0.BuildHas A B R.

Elpi Accumulate lp:{{
  % generate 2 functions of weakening per possible weakening:
  % one on the left and one on the right, if possible
  pred generate-forget i:param-class, i:univ, i:univ.variable.
  generate-forget (pc M N) U L :-
    coq.univ-instance UI [L],
    map-class->string M MStr,
    map-class->string N NStr,
    ModuleNameMN is "Param" ^ MStr ^ NStr,
    coq.locate {calc (ModuleNameMN ^ ".Rel")} RelMN,
    coq.locate {calc (ModuleNameMN ^ ".R")} RMN,
    coq.locate {calc (ModuleNameMN ^ ".covariant")} CovariantMN,
    coq.locate {calc (ModuleNameMN ^ ".contravariant")} ContravariantMN,
    % covariant weakening
    std.forall {map-class.weakenings-from M} (m1\
      sigma M1Str ModuleNameM1N BuildRelName BuildRelM1N ForgetMapName
            ForgetMapM Decl ForgetName Forget RelName RelM1N\ std.do! [
        map-class->string m1 M1Str,
        ModuleNameM1N is "Param" ^ M1Str ^ NStr,
        BuildRelName is ModuleNameM1N ^ ".BuildRel",
        coq.locate BuildRelName BuildRelM1N,
        ForgetMapName is "forgetMap" ^ MStr ^ M1Str,
        coq.locate ForgetMapName ForgetMapM,
        Decl =
          (fun `A` (sort (typ U)) a\ fun `B` (sort (typ U)) b\
            fun `P` (app [pglobal RelMN UI, a, b]) p\
              app [pglobal BuildRelM1N UI, a, b, app [pglobal RMN UI, a, b, p],
                app [pglobal ForgetMapM UI, a, b, app [pglobal RMN UI, a, b, p],
                  app [pglobal CovariantMN UI, a, b, p]],
                app [pglobal ContravariantMN UI, a, b, p]]),
        ForgetName is "forget_" ^ MStr ^ NStr ^ "_" ^ M1Str ^ NStr,
        @udecl! [L] ff [] ff =>
          coq.env.add-const ForgetName Decl _ @transparent! _,
        coq.locate ForgetName Forget,
        RelName is ModuleNameM1N ^ ".Rel",
        coq.locate RelName RelM1N,
        @global! => coq.coercion.declare (coercion Forget 2 RelMN (grefclass RelM1N))
    ]),
    % contravariant weakening
    coq.locate "sym_rel" SymRel,
    std.forall {map-class.weakenings-from N} (n1\
      sigma N1Str ModuleNameMN1 BuildRelName BuildRelMN1 ForgetMapName
            ForgetMapN Decl ForgetName Forget RelName RelMN1\ std.do! [
        map-class->string n1 N1Str,
        ModuleNameMN1 is "Param" ^ MStr ^ N1Str,
        BuildRelName is ModuleNameMN1 ^ ".BuildRel",
        coq.locate BuildRelName BuildRelMN1,
        ForgetMapName is "forgetMap" ^ NStr ^ N1Str,
        coq.locate ForgetMapName ForgetMapN,
        Decl =
          (fun `A` (sort (typ U)) a\ fun `B` (sort (typ U)) b\
            fun `P` (app [pglobal RelMN UI, a, b]) p\
              app [pglobal BuildRelMN1 UI, a, b, app [pglobal RMN UI, a, b, p],
                app [pglobal CovariantMN UI, a, b, p],
                app [pglobal ForgetMapN UI, b, a,
                  app [pglobal SymRel UI, a, b, app [pglobal RMN UI, a, b, p]],
                  app [pglobal ContravariantMN UI, a, b, p]]]),
        ForgetName is "forget_" ^ MStr ^ NStr ^ "_" ^ MStr ^ N1Str,
        @udecl! [L] ff [] ff =>
          coq.env.add-const ForgetName Decl _ @transparent! _,
        coq.locate ForgetName Forget,
        RelName is ModuleNameMN1 ^ ".Rel",
        coq.locate RelName RelMN1,
        @global! => coq.coercion.declare (coercion Forget 2 RelMN (grefclass RelMN1))
    ]).
}}.
Elpi Typecheck.

(* generate the hierarchy *)
Elpi Query lp:{{
  coq.univ.new U,
  coq.univ.variable U L,
  Classes = [map0, map1, map2a, map2b, map3, map4],
  std.forall Classes (m\
    std.forall Classes (n\
      generate-module (pc m n) U L,
      generate-forget (pc m n) U L
    )
  ).
}}.

(* Set Printing Universes. Print Module Param2a3. *)
(* Set Printing Universes. Print forget_42b_41. *)
(* Check forall (p : Param44.Rel nat nat), @paths (Param12a.Rel nat nat) p p. *)

(* General projections *)

Definition rel {A B} (R : Param00.Rel A B) := Param00.R A B R.
Coercion rel : Param00.Rel >-> Funclass.

Definition map {A B} (R : Param10.Rel A B) : A -> B :=
  Map1.map _ (Param10.covariant A B R).
Definition map_in_R {A B} (R : Param2a0.Rel A B) :
  forall (a : A) (b : B), map R a = b -> R a b :=
  Map2a.map_in_R _ (Param2a0.covariant A B R).
Definition R_in_map {A B} (R : Param2b0.Rel A B) :
  forall (a : A) (b : B), R a b -> map R a = b :=
  Map2b.R_in_map _ (Param2b0.covariant A B R).
Definition R_in_mapK {A B} (R : Param40.Rel A B) :
  forall (a : A) (b : B), map_in_R R a b o R_in_map R a b == idmap :=
  Map4.R_in_mapK _ (Param40.covariant A B R).

Definition comap {A B} (R : Param01.Rel A B) : B -> A :=
  Map1.map _ (Param01.contravariant A B R).
Definition comap_in_R {A B} (R : Param02a.Rel A B) :
  forall (b : B) (a : A), comap R b = a -> R a b :=
  Map2a.map_in_R _ (Param02a.contravariant A B R).
Definition R_in_comap {A B} (R : Param02b.Rel A B) :
  forall (b : B) (a : A), R a b -> comap R b = a :=
  Map2b.R_in_map _ (Param02b.contravariant A B R).
Definition R_in_comapK {A B} (R : Param04.Rel A B) :
  forall (b : B) (a : A), comap_in_R R b a o R_in_comap R b a == idmap :=
  Map4.R_in_mapK _ (Param04.contravariant A B R).

(* Aliasing *)

Declare Scope param_scope.
Local Open Scope param_scope.
Delimit Scope param_scope with P.

Notation UParam := Param44.Rel.
Notation MkUParam := Param44.BuildRel.
Notation "A <=> B" := (Param44.Rel A B) : param_scope.
Notation IsUMap := Map4.Has.
Notation MkUMap := Map4.BuildHas.
Arguments Map4.BuildHas {A B R}.
Arguments Param44.BuildRel {A B R}.

(* symmetry lemmas for Map *)

Definition eq_Map0@{i} {A A' : Type@{i}} {R R' : A -> A' -> Type@{i}} :
  (forall a a', R a a' <~> R' a a') ->
  Map0.Has@{i} R' -> Map0.Has@{i} R.
Proof.
  move=> RR' []; exists.
Defined.

Definition eq_Map1@{i} {A A' : Type@{i}} {R R' : A -> A' -> Type@{i}} :
  (forall a a', R a a' <~> R' a a') ->
  Map1.Has@{i} R' -> Map1.Has@{i} R.
Proof.
  move=> RR' [m]; exists. exact.
Defined.

Definition eq_Map2a@{i} {A A' : Type@{i}} {R R' : A -> A' -> Type@{i}} :
  (forall a a', R a a' <~> R' a a') ->
  Map2a.Has@{i} R' -> Map2a.Has@{i} R.
Proof.
  move=> RR' [m mR]; exists m.
  move=> a' b /mR /(RR' _ _)^-1%equiv; exact.
Defined.

Definition eq_Map2b@{i} {A A' : Type@{i}} {R R' : A -> A' -> Type@{i}} :
  (forall a a', R a a' <~> R' a a') ->
  Map2b.Has@{i} R' -> Map2b.Has@{i} R.
Proof.
  move=> RR' [m Rm]; unshelve eexists m.
  - move=> a' b /(RR' _ _)/Rm; exact.
Defined.

Definition eq_Map3@{i} {A A' : Type@{i}} {R R' : A -> A' -> Type@{i}} :
  (forall a a', R a a' <~> R' a a') ->
  Map3.Has@{i} R' -> Map3.Has@{i} R.
Proof.
  move=> RR' [m mR Rm]; unshelve eexists m.
  - move=> a' b /mR /(RR' _ _)^-1%equiv; exact.
  - move=> a' b /(RR' _ _)/Rm; exact.
Defined.

Definition eq_Map4@{i} {A A' : Type@{i}} {R R' : A -> A' -> Type@{i}} :
  (forall a a', R a a' <~> R' a a') ->
  Map4.Has@{i} R' -> Map4.Has@{i} R.
Proof.
move=> RR' [m mR Rm RmK]; unshelve eexists m _ _.
- move=> a' b /mR /(RR' _ _)^-1%equiv; exact.
- move=> a' b /(RR' _ _)/Rm; exact.
- by move=> a' b r /=; rewrite RmK [_^-1%function _]equiv_funK.
Defined.

(* joined elimination of comap and comap_in_R *)

Definition comap_ind {A A' : Type} {PA : Param04.Rel A A'}
    (a : A) (a' : A') (aR : PA a a')
    (P : forall (a : A), PA a a' -> Type)  :
   P a aR -> P (comap PA a') (comap_in_R PA a' (comap PA a') idpath).
Proof.
apply (transport
  (fun aR0 : PA a a' =>
    P a aR0 -> P (comap PA a')
                 (comap_in_R PA a' (comap PA a') idpath))
  (R_in_comapK PA a' a aR)
  (paths_rect A (comap PA a')
  (fun (a0 : A) (e : comap PA a' = a0) =>
   P a0 (comap_in_R PA a' a0 e) ->
   P (comap PA a')
    (comap_in_R PA a' (comap PA a') idpath)) idmap a
  (R_in_comap PA a' a aR))).
Defined.

(* proofs about Param44 *)

Lemma umap_equiv_sigma (A B : Type@{i}) (R : A -> B -> Type@{i}) :
  IsUMap R <~>
    { map : A -> B |
    { mR : forall (a : A) (b : B), map a = b -> R a b |
    { Rm : forall (a : A) (b : B), R a b -> map a = b |
      forall (a : A) (b : B), mR a b o Rm a b == idmap } } }.
Proof. by symmetry; issig. Defined.

Lemma umap_equiv_isfun `{Funext} {A B : Type@{i}}
  (R : A -> B -> Type@{i}) : IsUMap R <~> IsFun R.
Proof.
apply (equiv_composeR' (umap_equiv_sigma _ _ R)).
transitivity (forall x : A, {y : B & {r : R x y & forall yr', (y; r) = yr'}});
last first. {
  apply equiv_functor_forall_id => a.
  apply (equiv_compose' (issig_contr _)).
  apply equiv_sigma_assoc'.
}
apply (equiv_compose' (equiv_sig_coind _ _)).
apply equiv_functor_sigma_id => map.
apply (equiv_compose' (equiv_sig_coind _ _)).
apply (equiv_composeR' (equiv_sigma_symm _)).
transitivity {f : forall x, R x (map x) &
  forall (x : A) (y : B) (r :  R x y), (map x; f x) = (y; r)};
last first. {
  apply equiv_functor_sigma_id => comap.
  apply equiv_functor_forall_id => a.
  exact: (equiv_composeR' equiv_forall_sigma).
}
transitivity
  { f : forall x, R x (map x) &
    forall (x : A) (y : B) (r :  R x y), {e : map x = y & e # f x = r} };
last first. {
  apply equiv_functor_sigma_id => comap.
  apply equiv_functor_forall_id => a.
  apply equiv_functor_forall_id => b.
  apply equiv_functor_forall_id => r.
  apply (equiv_compose' equiv_path_sigma_dp).
  apply equiv_functor_sigma_id => e.
  exact: equiv_dp_path_transport.
}
transitivity
  { f : forall x, R x (map x) &
    forall x y, {g : forall (r :  R x y), map x = y &
    forall (r :  R x y), g r # f x = r } };
last first. {
  apply equiv_functor_sigma_id => comap.
  apply equiv_functor_forall_id => a.
  apply equiv_functor_forall_id => b.
  exact: equiv_sig_coind.
}
transitivity  { f : forall x, R x (map x) &
    forall x, { g : forall (y : B) (r :  R x y), map x = y &
                forall (y : B) (r :  R x y), g y r # f x = r } };
last first. {
  apply equiv_functor_sigma_id => comap.
  apply equiv_functor_forall_id => a.
  exact: equiv_sig_coind.
}
transitivity
  { f : forall x, R x (map x) &
    {g : forall (x : A) (y : B) (r :  R x y), map x = y &
         forall x y r, g x y r # f x = r } };
last first.
{ apply equiv_functor_sigma_id => comap; exact: equiv_sig_coind. }
apply (equiv_compose' (equiv_sigma_symm _)).
apply equiv_functor_sigma_id => Rm.
transitivity
  { g : forall (x : A) (y : B) (e : map x = y), R x y &
    forall (x : A) (y : B) (r : R x y), Rm x y r # g x (map x) idpath = r }. {
  apply equiv_functor_sigma_id => mR.
  apply equiv_functor_forall_id => a.
  apply equiv_functor_forall_id => b.
  apply equiv_functor_forall_id => r.
  unshelve econstructor. { apply: concat. elim (Rm a b r). reflexivity. }
  unshelve econstructor. { apply: concat. elim (Rm a b r). reflexivity. }
  all: move=> r'; elim r'; elim (Rm a b r); reflexivity.
}
symmetry.
unshelve eapply equiv_functor_sigma.
- move=> mR a b e; exact (e # mR a).
- move=> mR mRK x y r; apply: mRK.
- apply: isequiv_biinv.
  split; (unshelve eexists; first by move=> + a; apply) => //.
  move=> r; apply path_forall => a; apply path_forall => b.
  by apply path_arrow; elim.
- by move=> mR; unshelve econstructor.
Defined.

Lemma uparam_equiv `{Univalence} {A B : Type} : (A <=> B) <~> (A <~> B).
Proof.
apply (equiv_compose' equiv_sig_relequiv^-1).
unshelve eapply equiv_adjointify.
- move=> [R mR msR]; exists R; exact: umap_equiv_isfun.
- move=> [R mR msR]; exists R; exact: (umap_equiv_isfun _)^-1%equiv.
- by move=> [R mR msR]; rewrite !equiv_invK.
- by move=> [R mR msR]; rewrite !equiv_funK.
Defined.

Definition id_umap {A : Type} : IsUMap (@paths A) :=
  MkUMap idmap (fun a b r => r) (fun a b r => r) (fun a b r => 1%path).

Definition id_sym_umap {A : Type} : IsUMap (sym_rel (@paths A)) :=
  MkUMap idmap (fun a b r => r^) (fun a b r => r^) (fun a b r => inv_V r).

Definition id_uparam {A : Type} : A <=> A :=
  MkUParam id_umap id_sym_umap.

Lemma uparam_induction `{Univalence} A (P : forall B, A <=> B -> Type) :
  P A id_uparam -> forall B f, P B f.
Proof.
move=> PA1 B f; rewrite -[f]/(B; f).2 -[B]/(B; f).1.
suff : (A; id_uparam) = (B; f). { elim. done. }
apply: path_ishprop; apply: hprop_inhabited_contr => _.
apply: (contr_equiv' {x : _ & A = x}).
apply: equiv_functor_sigma_id => {f} B.
symmetry; apply: equiv_compose' uparam_equiv.
exact: equiv_path_universe.
Defined.

Lemma uparam_equiv_id `{Univalence} A :
  uparam_equiv (@id_uparam A) = equiv_idmap.
Proof. exact: path_equiv. Defined.

(* instances of MapN for A = A *)
(* allows to build id_ParamMN : forall A, ParamMN.Rel A A *)

Definition id_Map0 {A : Type} : Map0.Has (@paths A).
Proof. constructor. Defined.

Definition id_Map0_sym {A : Type} : Map0.Has (sym_rel (@paths A)).
Proof. constructor. Defined.

Definition id_Map1 {A : Type} : Map1.Has (@paths A).
Proof. constructor. exact idmap. Defined.

Definition id_Map1_sym {A : Type} : Map1.Has (sym_rel (@paths A)).
Proof. constructor. exact idmap. Defined.

Definition id_Map2a {A : Type} : Map2a.Has (@paths A).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun a b e => e).
Defined.

Definition id_Map2a_sym {A : Type} : Map2a.Has (sym_rel (@paths A)).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun A B e => e^).
Defined.

Definition id_Map2b {A : Type} : Map2b.Has (@paths A).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun a b e => e).
Defined.

Definition id_Map2b_sym {A : Type} : Map2b.Has (sym_rel (@paths A)).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun A B e => e^).
Defined.

Definition id_Map3 {A : Type} : Map3.Has (@paths A).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun a b e => e).
  - exact (fun a b e => e).
Defined.

Definition id_Map3_sym {A : Type} : Map3.Has (sym_rel (@paths A)).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun A B e => e^).
  - exact (fun A B e => e^).
Defined.

Definition id_Map4 {A : Type} : Map4.Has (@paths A).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun a b e => e).
  - exact (fun a b e => e).
  - exact (fun a b e => 1%path).
Defined.

Definition id_Map4_sym {A : Type} : Map4.Has (sym_rel (@paths A)).
Proof.
  unshelve econstructor.
  - exact idmap.
  - exact (fun A B e => e^).
  - exact (fun A B e => e^).
  - exact (fun A B e => inv_V e).
Defined.

(* generate id_ParamMN : forall A, ParamMN.Rel A A for all M N *)

Elpi Accumulate lp:{{
  pred generate-id-param i:param-class, i:univ, i:univ.variable.
  generate-id-param (pc M N) U L :-
    map-class->string M MStr,
    map-class->string N NStr,
    coq.univ-instance UI [L],
    coq.locate {calc ("Param" ^ MStr ^ NStr ^ ".BuildRel")} BuildRel,
    coq.locate "paths" Paths,
    coq.locate {calc ("id_Map" ^ MStr)} IdMap,
    coq.locate {calc ("id_Map" ^ NStr ^ "_sym")} IdMapSym,
    Decl =
      (fun `A` (sort (typ U)) a\
        app [pglobal BuildRel UI, a, a, app [pglobal Paths UI, a],
          app [pglobal IdMap UI, a],
          app [pglobal IdMapSym UI, a]]),
    IdParam is "id_Param" ^ MStr ^ NStr,
    @udecl! [L] ff [] ff => coq.env.add-const IdParam Decl _ @transparent! _.
}}.
Elpi Typecheck.

Elpi Query lp:{{
  coq.univ.new U,
  coq.univ.variable U L,
  Classes = [map0, map1, map2a, map2b, map3, map4],
  std.forall Classes (m\
    std.forall Classes (n\
      generate-id-param (pc m n) U L
    )
  ).
}}.

(* Check id_Param00. *)
(* Check id_Param32b. *)

(* symmetry property for Param *)

Elpi Accumulate lp:{{
  pred generate-param-sym i:param-class, i:univ, i:univ.variable.
  generate-param-sym (pc M N) U L :-
    map-class->string M MStr,
    map-class->string N NStr,
    coq.univ-instance UI [L],
    coq.locate {calc ("Param" ^ MStr ^ NStr ^ ".Rel")} RelMN,
    coq.locate {calc ("Param" ^ NStr ^ MStr ^ ".BuildRel")} BuildRelNM,
    coq.locate "sym_rel" SymRel,
    coq.locate {calc ("Param" ^ MStr ^ NStr ^ ".R")} RMN,
    coq.locate {calc ("Param" ^ MStr ^ NStr ^ ".covariant")} CovariantMN,
    coq.locate
      {calc ("Param" ^ MStr ^ NStr ^ ".contravariant")} ContravariantMN,
    Decl =
      (fun `A` (sort (typ U)) a\ fun `B` (sort (typ U)) b\
        fun `P` (app [pglobal RelMN UI, a, b]) p\
          app [pglobal BuildRelNM UI, b, a,
            app [pglobal SymRel UI, a, b, app [pglobal RMN UI, a, b, p]],
            app [pglobal ContravariantMN UI, a, b, p],
            app [pglobal CovariantMN UI, a, b, p]
          ]),
    ParamSym is "Param" ^ MStr ^ NStr ^ "_sym",
    @udecl! [L] ff [] ff => coq.env.add-const ParamSym Decl _ @transparent! _.
}}.
Elpi Typecheck.

Elpi Query lp:{{
  coq.univ.new U,
  coq.univ.variable U L,
  Classes = [map0, map1, map2a, map2b, map3, map4],
  std.forall Classes (m\
    std.forall Classes (n\
      generate-param-sym (pc m n) U L
    )
  ).
}}.

(* Check Param33_sym.
Check Param2a4_sym. *)
