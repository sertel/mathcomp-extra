
(******************************************************************************)
(*            Sudoku.v:                                                       *)
(*     Checking and Solving Sudokus                                           *)
(*                               thery@sophia.inria.fr                        *)
(*     Definitions:                                                           *)
(*      sudoku, check, find_one, find_all                                     *)
(*                                      (2022)                                *)
(******************************************************************************)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

From mathcomp Require Import all_ssreflect.
From mathcomp Require Import zify.

Section sudoku.

(******************************************************************************)
(* About the encoding:                                                        *)
(*  h represents the number of rows of a little rectangle                     *)
(*  w represents the number of columns of a little rectangle                  *)
(*  hw represents the number of cells of a little rectangle                   *)
(* the initial grid is then composed of (hw * hw) cells                       *)
(* For example for the usual sudoku                                           *)
(*   h = 3, w = 3, hw = 9, the grid = 81 cells                                *)
(* The grid is represented by a seq of (hw * hw) cells                       *)
(* at the position (x,y) of the seq (i.e at the index (x * hw + y))          *)
(* if the cell is empty it contains 0, otherwise its contains one of          *)
(* the numbers 1,2, ; auto., hw                                               *)
(******************************************************************************)

(* Height h and width w *)
Variable h w : nat.

(* Size *)
Definition hw := h * w.

Lemma h_pos x : x < hw -> 0 < h.
Proof. by rewrite /hw; case: h. Qed.

Lemma w_pos x : x < hw -> 0 < w.
Proof. by rewrite /hw; case: w; rewrite 1?mulnC. Qed.

Lemma hw_divh x : x < hw -> x %/ h < w.
Proof. by move=> xLhw; rewrite ltn_divLR 1?mulnC // (h_pos xLhw). Qed.

Lemma hw_divw x : x < hw -> x %/ w < h.
Proof. by move=> xLhw; rewrite ltn_divLR // (w_pos xLhw). Qed.

Lemma hw_modh x : x < hw -> x %% h < h.
Proof. by move=> xLhw; rewrite ltn_mod (h_pos xLhw). Qed.

Lemma hw_modw x : x < hw -> x %% w < w.
Proof. by move=> xLhw; rewrite ltn_mod // (w_pos xLhw). Qed.

Lemma hw_MhD x y : x < w -> y < h -> x * h + y < hw.
Proof. by rewrite /hw; nia. Qed.

Lemma hw_MwD x y : x < h -> y < w -> x * w + y < hw.
Proof. by rewrite /hw; nia. Qed.

Lemma hw_divhMD x1 z1 : x1 < hw -> z1 < h -> x1 %/ h * h + z1 < hw.
Proof. by move=> x1Lhw z1Lh; apply: hw_MhD => //; apply: hw_divh. Qed.

Lemma hw_divwMD y1 z1 : y1 < hw -> z1 < w -> y1 %/ w * w + z1 < hw.
Proof. by move=> x1Lhw z1Lh; apply: hw_MwD => //; apply: hw_divw. Qed.

Lemma hw_modwMDmod y1 z1 : y1 < hw -> z1 < hw -> y1 %% h * w + z1 %% w < hw.
Proof.
by move=> x1Lhw z1Lh; apply: hw_MwD; [apply: hw_modh|apply: hw_modw].
Qed.

(* The reference seq [1; 2; ; auto.; hw] *)
Definition sref := iota 1 hw.

Lemma sref_uniq : uniq sref.
Proof. apply: iota_uniq. Qed.

Lemma size_sref : size sref = hw.
Proof. by rewrite size_iota. Qed. 

(* The position indexes [0; 1; 2; ; hw -1] *)
Definition indexes := iota 0 hw.

Lemma size_indexes : size indexes = hw.
Proof. by rewrite size_iota. Qed.

(* Defines the indices *)
Lemma in_indexes i : (i \in indexes) = (i < hw).
Proof. by rewrite mem_iota. Qed.

(* An element outside the sref *)
Definition out := 0.

Lemma out_not_in_refl : out \notin sref.
Proof. by rewrite mem_iota /out; lia. Qed.

(* Empty grid (initial grid) *)
Definition init := nseq (hw * hw) out.

(* Its size is hw * hw *)
Lemma size_init : size init = hw * hw.
Proof. by rewrite size_nseq. Qed.

(******************************************************************************)
(*    Positions (x, y)                                                        *)
(******************************************************************************)

(* Define a position *)
Definition pos := (nat * nat)%type.

Implicit Types p : pos.

(* Shift a position *)
Definition shift p x y : pos := (x + p.1, y + p.2).

(* A position is valid if it is inside the board *)
Definition valid_pos p := (p.1 < hw) && (p.2 < hw).

(* Turn a position into a drop *)
Definition pos2n p := p.1 * hw + p.2.

Lemma pos2n00  : pos2n (0, 0) = 0.
Proof. by []. Qed.

Lemma pos2nK n : n < hw * hw -> pos2n (n %/ hw, n %% hw) = n.
Proof.
by rewrite /pos2n; case: hw => // hw1 _; rewrite /pos2n /= -divn_eq.
Qed.

Lemma valid_pos_pos2n_lt p : valid_pos p -> pos2n p < hw * hw.
Proof. by case: p => x y /andP[/= Hx Hy]; rewrite /pos2n /=; nia. Qed.

(* Positions are unique *)
Lemma valid_pos_eq p1 p2 :
    valid_pos p1 -> valid_pos p2 -> pos2n p1 = pos2n p2 -> p1 = p2.
Proof.
case: p1 => x1 y1; case: p2 => x2 y2.
rewrite /valid_pos /pos2n /= =>/andP[x1L y1L] /andP[x2L y2L] HH;
    congr (_ , _).
  apply: etrans (_ : (x1 * hw + y1) %/ hw = _).
    by rewrite divnMDl ?divn_small; lia.
  by rewrite HH divnMDl ?divn_small; lia.
apply: etrans (_ : (x1 * hw + y1) %% hw = _).
  by rewrite modnMDl ?modn_small; lia.
by rewrite HH modnMDl ?modn_small; lia.
Qed.

(* Find the next position *)
Definition next p : pos :=
  if hw == p.2.+1 then (p.1.+1, 0) else (p.1, p.2.+1).

Lemma next_pos p : pos2n (next p) = S (pos2n p).
Proof.
case: p => x y; rewrite /next /pos2n /=.
case: eqP=> Hw /=; lia.
Qed.

Lemma valid_pos_next p :
  valid_pos p -> pos2n (next p) < hw * hw -> valid_pos (next p).
Proof.
case: p => x y; rewrite /next /pos2n /valid_pos /= => /andP[Hx Hy].
case: eqP => Hw /=; nia.
Qed.

Lemma valid_pos2n p (s : seq nat) : 
  valid_pos p -> size s = hw * hw -> pos2n p < size s.
Proof.
case: p => x y; rewrite /valid_pos /pos2n /= => /andP[Hx Hy].
nia.
Qed.

Definition order_pos :=
   [rel p1 p2 | (p1.1 < p2.1) || ((p1.1 == p2.1) && (p1.2 <= p2.2))].

Lemma order_pos_refl p : reflexive order_pos.
Proof. by move=> [x y]; rewrite /= ltnn eqxx leqnn. Qed.

Lemma order_pos_trans : transitive order_pos.
Proof. 
move=> [x1 y1] [x2 y2] [x3 y3] /= /orP[x2Lx1|/andP[/eqP-> y2Ly1]].
  case/orP => [x1Lx3| /andP[/eqP<-]]; last by rewrite x2Lx1.
  by rewrite (ltn_trans x2Lx1 x1Lx3).
by case/orP => [->//|/andP[-> y1Ly3]]; rewrite (leq_trans y2Ly1) // orbT.
Qed.

Lemma order_next_anti p1 p2 :
  p1 != p2 -> order_pos p1 p2 = ~~ (order_pos p2 p1).
Proof.
case: p1 => x1 y1; case: p2 => x2 y2 /=.
by rewrite xpair_eqE negb_and; do 2 case: ltngtP.
Qed.

Lemma order_next_pos p1 p2 :
  p1 != p2 -> valid_pos p1 -> valid_pos p2 -> 
  order_pos p1 p2 = order_pos (next p1) p2.
Proof.
case: p1 => x1 y1; case: p2 => x2 y2.
rewrite xpair_eqE negb_and /valid_pos /next /= =>
  p1Dp2 /andP[/= Hx1 Hy1] /andP[/= Hx2 Hy2].
repeat (case: eqP => //= ?); repeat (case: leqP => //= ?); lia.
Qed.

Lemma order_pos_00 p : order_pos (0, 0) p.
Proof.  by case: p => x y; rewrite /= andbT; case: ltngtP. Qed.

(* Create the seq of positions (x, y) such that 0 <= x < h and 0 <= y < w *)
Definition cross := [seq (x, y) | x <- iota 0 h , y <- iota 0 w].

Lemma crossP p : p \in cross = ((p.1 < h) && (p.2 < w)).
Proof.
apply/allpairsP/idP=> [[[x1 y1]/= []]|/andP[Hh Hw]].
  by rewrite !mem_iota !andTb !add0n => Hx Hy -> /=; apply/andP.
by exists p; split; rewrite ?mem_iota // -surjective_pairing.
Qed.

(* Create the seq of pairs (x, y) such that 0 <= x < hw and 1 <= y <= hw *)
Definition cross1 := [seq (x, y) | x <- indexes , y <- sref].

Lemma cross1P p : p \in cross1 = ((p.1 \in indexes) && (p.2 \in sref)).
Proof.
apply/allpairsP/idP=> [[[x1 y1]/= [Hx1 Hy1 ->]]|/andP[Hh Hw]].
  by rewrite Hx1.
by exists p; rewrite Hh Hw -surjective_pairing.
Qed.

(* Create the seq of positions (x, y) such that                              *)
(*   0 <= x < hw and 0 <= y < hw1                                             *)
Definition cross2 := [seq (x, y) | x <- indexes , y <- indexes].

Lemma cross2_uniq : uniq cross2.
Proof.
apply: allpairs_uniq.
- apply: iota_uniq.
- apply: iota_uniq.
by move=> [x1 y1] [x2 y2].
Qed.

Lemma valid_pos_cross2 : all valid_pos cross2.
Proof.
apply/all_allpairsP=> x y.
by rewrite !mem_iota /= add0n /valid_pos => ->.
Qed.

Lemma mem_cross2 p : (p \in cross2) = valid_pos p.
Proof.
case: p => x1 y1; rewrite /valid_pos /=.
apply/allpairsP/idP => [[[x2 y2] /=]|/andP[x1Lw y1Lw]].
  by rewrite !mem_iota /= add0n => [] [xLhw yLhw [-> ->]]; rewrite xLhw.
by exists (x1, y1); rewrite !mem_iota; split.
Qed.

(******************************************************************************)
(*    Get                                                                     *)
(******************************************************************************)

(* Get the element of the seq s at position (x, y) *)
Definition get p s := nth out s (pos2n p).

(* Getting from a nil seq always returns 0 *)
Lemma get_nil p : get p [::] = out.
Proof. by rewrite /get nth_default. Qed.

(* The init always returns a non-value *)
Lemma get_init p : get p init \notin sref.
Proof. by rewrite /get nth_nseq if_same out_not_in_refl. Qed.

(* Relation between get and next *)
Lemma get_next p a s : get (next p) (a :: s) = get p s.
Proof. by rewrite /get next_pos. Qed.

(* m is full of zero *)
Lemma get_nseq n p : get p (nseq n out) = out.
Proof. by rewrite /get nth_nseq if_same. Qed.

(******************************************************************************)
(*    Update                                                                  *)
(******************************************************************************)

(* Update the seq l at the position (x, y) with the value v *)
Fixpoint subst (A : Type) (n : nat) (v : A) (l : seq A) : seq A :=
  if l is a :: l1 then
    if n is n1.+1 then a :: subst n1 v l1 else v :: l1
  else [::].

Lemma substE A n (v : A) s : 
  subst n v s = if n < size s then take n s ++ (v :: drop n.+1 s) else s.
Proof.
elim: n s => /=  [[|a s]|/= n IH [|a s]] //=; first by rewrite drop0.
by rewrite {}IH ltnS; case: leqP.
Qed.

Lemma size_subst A n (v : A) s : size (subst n v s) = size s.
Proof.
rewrite substE; case: leqP => //=; rewrite size_cat /= size_take size_drop.
case: leqP => [sLn|nLs] //= _.
by rewrite -subSn // subSS addnC subnK // ltnW.
Qed.
Definition update p v (s : seq nat) := subst (pos2n p) v s.

(* The size after an update is unchanged *)
Lemma size_update p v s : size (update p v s) = size s.
Proof. by rewrite /update size_subst. Qed.

Check valid_pos2n.

(* Getting the updated cell gives the new value *)
Lemma update_get p v s :
  size s = hw * hw -> valid_pos p -> get p (update p v s) = v.
Proof.
move=> Hs Hp; have := valid_pos2n Hp Hs.
rewrite /update /get substE => pLs.
by rewrite pLs nth_cat size_take pLs ltnn subnn.
Qed.

(* Getting outside the updated cell returns the previous value *)
Lemma update_diff_get p1 p2 v s :
  valid_pos p1 -> valid_pos p2 -> p1 != p2 -> get p1 (update p2 v s) = get p1 s.
Proof.
move=> Vp1 Vp2 p1Dp2.
rewrite /get /update substE; case: leqP => //= p2Ls.
rewrite nth_cat size_take p2Ls.
case: leqP => p2Lp1; last by rewrite nth_take.
rewrite leq_eqVlt in p2Lp1; have /orP[/eqP pp2Epp1|pp2Lpp1] := p2Lp1.
  by case/eqP : p1Dp2; apply: valid_pos_eq.
rewrite -[_ - _]prednK ?subn_gt0 //= nth_drop.
by rewrite addSnnS prednK ?subn_gt0 // addnC subnK // ltnW.
Qed.

(******************************************************************************)
(*    Restrict till position                                                  *)
(******************************************************************************)

Definition prestrict p s := 
  let n1 := pos2n p in 
  if n1 < size s then take n1 s ++ (nseq (size s - n1) out) else s.

Lemma prestrict_0 s : prestrict (0, 0) s = nseq (size s) out.
Proof. by case: s. Qed.

Lemma prestrict_all p s : size s <= pos2n p -> prestrict p s = s.
Proof. by move=> sLp; rewrite /prestrict ltnNge sLp. Qed.

Lemma prestrict_size p s : size (prestrict p s) = (size s).
Proof.
rewrite /prestrict; case: leqP => // pLs.
by rewrite size_cat size_take pLs size_nseq addnC subnK // ltnW.
Qed.

Lemma prestrict_update p s :
  pos2n (next p) <= size s ->
  prestrict (next p) s = update p (get p s) (prestrict p s).
Proof.
rewrite /prestrict /get /update substE next_pos.
rewrite leq_eqVlt => /orP[/eqP He|pLs].
  have pLs : pos2n p < size s by rewrite He.
  rewrite He ltnn eqxx /= size_cat size_take.
  rewrite size_nseq pLs addnC subnK; last by rewrite ltnW.
  rewrite leqnn take_cat size_take pLs ltnn subnn take0 cats0.
  rewrite drop_cat size_take pLs ltnNge (ltnW pLs) /= drop_nseq subnn //=.
  rewrite -[LHS](cat_take_drop (pos2n p)) //.
  by rewrite (drop_nth out) // drop_oversize // He.
have pLs1 : pos2n p < size s by rewrite ltnW.
rewrite pLs orbT size_cat size_nseq size_take pLs1 ifT; last first.
  by rewrite addnC subnK // ltnW.
rewrite take_cat drop_cat !size_take !pLs1 ltnn ifN -?leqNgt ?leqnS //.
rewrite subSn // subnn take0 cats0 drop_nseq subn1 subnS.
by rewrite -cat_rcons (take_nth out).
Qed.

Lemma prestrict_get s p q :
  pos2n p < pos2n q -> get p (prestrict q s) = get p s.
Proof.
move=> pLq; rewrite /get /prestrict.
case: leqP => // qLs.
by rewrite nth_cat size_take qLs pLq nth_take.
Qed.

Lemma prestrict_get_default s p q :
  pos2n q <= pos2n p -> get p (prestrict q s) = out.
Proof.
move=> qLp; rewrite /get /prestrict.
case: leqP => [sLq|qLs].
  by rewrite nth_default // (leq_trans sLq).
by rewrite nth_cat size_take qLs ltnNge qLp /= nth_nseq if_same.
Qed.

(******************************************************************************)
(*    Refine                                                                  *)
(******************************************************************************)

(* A state refines another if it has only substitutes non sref element    *)
Definition refine s1 s2 :=
  [&& size s1 == hw * hw,
      size s2 == hw * hw &
      [forall n : 'I_(hw * hw), 
        let p := (n %/ hw, n %% hw) in 
        (get p s1 \in sref) ==> (get p s1 == get p s2)]].

Lemma refineP s1 s2 : 
  reflect 
     [/\ size s1 = hw * hw,
         size s2 = hw * hw &
         forall p, valid_pos p -> get p s1 \in sref -> get p s1 = get p s2]
     (refine s1 s2).
Proof.
apply: (iffP and3P) => [[/eqP Heq1 /eqP Heq2 /forallP /= Hf]|
                        [Heq1 Heq2 Hf]]; split => //; try by apply/eqP.
  move=> [x y] Hp.
  have /implyP := Hf (Ordinal (valid_pos_pos2n_lt Hp)).
  rewrite /get pos2nK /= //.
  by move=> Hk Hg; have /eqP := (Hk Hg).
  by apply: valid_pos_pos2n_lt.
apply/forallP=> /= n; rewrite /get pos2nK //.
have hw_pos : 0 < hw.
  suff : 0 < hw * hw by case: hw.
  by apply: leq_ltn_trans (ltn_ord n).
apply/implyP => Hg; apply/eqP.
have := Hf (n %/ hw, n %% hw).
rewrite /get pos2nK //; apply => //.
rewrite /valid_pos /= ltn_mod.
by rewrite ltn_divLR ?ltn_ord /=.
Qed.

Lemma refine_refl s : size s = hw * hw -> refine s s.
Proof. by move=> Hs; apply/refineP; split. Qed.

(* Refinement is transitive                                                   *)
Lemma refine_trans : transitive refine.
Proof.
move=> s1 s2 s3 /refineP[Hl1 Hr1 Hf1] /refineP[Hl2 Hr2 Hf2].
apply/refineP; split => //.
by move=> p Hv Hp; rewrite Hf1 // Hf2 // -Hf1.
Qed.

(* Every states refine the initial state *)
Lemma refine_init s : size s = hw * hw -> refine init s.
Proof.
move=> Hs; apply/refineP; split => //; first by apply size_init.
move=> p _; rewrite /init /get !nth_nseq if_same => H.
by case/negP: out_not_in_refl.
Qed.

(* update is a refinement *)
Lemma refine_update p v s :
  valid_pos p -> get p s \notin sref -> size s = hw * hw -> 
  refine s (update p v s).
Proof.
move=> Hp Hg Hs; apply/refineP; split=> //; first by rewrite size_update.
move=> p1 Hp1 Hg1.
have hw_gt0 : 0 < hw by case/andP: Hp1; case: hw.
by rewrite update_diff_get //; apply: contra Hg => /eqP<-.
Qed.

Lemma refine_prestrict p s :  size s = hw * hw -> refine (prestrict p s) s.
Proof.
move=> Hs.
apply/refineP; split => //.
  by rewrite prestrict_size.
move=> p1 Hp1.
case: (leqP (pos2n p) (pos2n p1)) => Lp.
  by rewrite prestrict_get_default // => HH; case/negP: out_not_in_refl.
by rewrite prestrict_get.
Qed.

(******************************************************************************)
(*    Empty                                                                   *)
(******************************************************************************)

(* A state is empty if it is full of zero *)
Definition empty s := all (fun x => x \notin sref) s.

Lemma emptyP s : reflect (forall p, get p s \notin sref) (empty s).
Proof.
apply: (iffP allP) => [Hs p|Hp x /nthP xIs].
  case: (leqP (size s) (pos2n p)) => [sLp|pLs]; last by apply/Hs/mem_nth.
  by rewrite [get _ _]nth_default // out_not_in_refl.
have [n [nLs <-]]:= xIs out.
by apply: (Hp (0 , n)).
Qed.

(* The empty seq is empty *)
Lemma empty_nil : empty nil.
Proof. by []. Qed.

Lemma empty_nseq n : empty (nseq n out).
Proof. by rewrite /empty all_nseq out_not_in_refl orbT. Qed.

(* Dropping an empty state gives an empty state *)
Lemma empty_drop n s : empty s -> empty (drop n s).
Proof. 
move=>/emptyP Hp; apply/emptyP => p.
rewrite /get nth_drop.
by apply: (Hp (0, n + pos2n p)).
Qed.

(* A state that starts with an element not in the sref
   is empty if its tail is empty *)
Lemma empty_cons a s : a \notin sref -> empty s -> empty (a :: s).
Proof.
move=> aNIs /emptyP He; apply/emptyP => p.
by rewrite /get; case: pos2n => //= n; apply: (He (0, n)).
Qed.

(* Inversion theorem for empty *)
Lemma empty_inv a s : empty (a :: s) -> a \notin sref /\ empty s.
Proof.
move=> /emptyP He; split; first by apply: (He (0, 0)).
by apply/emptyP => p; apply: (He (0, (pos2n p).+1)).
Qed.

(* For a take to be empty it is sufficient the state to be empty *)
Lemma empty_take n s : empty s -> empty (take n s).
Proof.
by rewrite /empty -{1}(@cat_take_drop n _ s) all_cat => /andP[].
Qed.

(******************************************************************************)
(*    Rows                                                                    *)
(******************************************************************************)

Definition row i (s : seq nat) := take hw (drop (i * hw) s).

Lemma size_row i s :
  i < hw -> size s = hw * hw -> size (row i s) = hw.
Proof.
move=> iLhw Hs; rewrite size_take size_drop.
case: leqP => //; nia.
Qed.

(* Relation between get and row *)
Lemma get_row x y s : y < hw -> get (x, y) s = nth out (row x s) y.
Proof.
by move=> yLhw; rewrite /get /row /pos2n /= nth_take // nth_drop.
Qed.

(******************************************************************************)
(*    Columns                                                                 *)
(******************************************************************************)

Fixpoint take_and_drop (A : Type) (t d n : nat) (s :  seq A) :=
  if n is n1.+1 then take t s ++ take_and_drop t d n1 (drop d s) else [::]. 

Lemma nth_take_and_drop (A : Type) (a : A) t d m n s :
  0 < t <= d -> m < n * t ->  n.-1 * d + t <= size s ->
  nth a (take_and_drop t d n s) m = nth a s ((m %/ t) * d + m %% t).
Proof.
move=> /andP[t_gt0 tLd].
elim: n m s => //= n IH m s mLtd tdLs.
have tLs : t <= size s.
  by rewrite (leq_trans _ tdLs) // leq_addl.
rewrite nth_cat size_take_min (minn_idPl _) //.
case: leqP => [tLm|mLt]; last first.
  by rewrite divn_small // add0n modn_small // nth_take.
rewrite {}IH //.
- rewrite nth_drop -{3 4}(subnK tLm).
  by rewrite divnDr ?divnn // t_gt0 addn1 mulSn addnA modnDr.
- by rewrite ltn_subLR.
case: n mLtd tdLs => [|n mLtd tdLs]; first by rewrite mul1n ltnNge tLm.
rewrite size_drop leq_subRL //=; first by rewrite addnA -mulSn.
by apply: leq_trans tdLs; rewrite mulSn -addnA leq_addr.
Qed.

Theorem take_and_drop_nil (A : Type) t d n :
  take_and_drop t d n [::] = [::] :> seq A.
Proof. by elim: n. Qed.

Theorem size_take_and_drop (A : Type) t d n (s : seq A) :
  n.-1 * d + t <= size s -> 
  size (take_and_drop t d n s) = n * t.
Proof.
elim: n s => [/= //|/= [|n] IH s tLs]; rewrite ?addn0 in tLs.
  rewrite size_cat size_take addn0 mul1n; case: ltngtP => //.
  by rewrite ltnNge tLs.
rewrite size_cat size_take IH; last first.
  rewrite size_drop leq_subRL; first by rewrite addnA.
  by rewrite (leq_trans _ tLs) // mulSn -addnA leq_addr.
case: ltngtP => [||<-] //.
by rewrite ltnNge (leq_trans _ tLs) // leq_addl.
Qed.

Definition column i (l : seq nat) := take_and_drop 1 hw hw (drop i l).

Lemma size_column j s :
  j < hw -> size s = hw * hw -> size (column j s) = hw.
Proof.
move=> jLhw Hs.
rewrite size_take_and_drop ?muln1 // size_drop {}Hs.
rewrite addn1; nia.
Qed.

(* Relation between get and column *)
Lemma get_column x y s :
  size s = hw * hw -> x < hw -> y < hw -> 
  get (x, y) s = nth out (column y s) x.
Proof.
move=> Hs xLhw yLhw.
rewrite /get /column /pos2n nth_take_and_drop ?muln1 //=.
- by rewrite nth_drop divn1 modn1 addn0 addnC.
- by apply: leq_ltn_trans xLhw.
rewrite size_drop addn1 Hs; nia.
Qed.

(******************************************************************************)
(*    SubRectangles                                                           *)
(******************************************************************************)

(* The subrectangles *)
Definition rect i (s : seq nat) :=
  take_and_drop w hw h (drop (w * (i %% h) +  h * (i %/ h) * hw) s).

(* Relation between get and rect *)
Lemma get_rect x y s :
  size s = hw * hw -> x < hw -> y < hw ->
  get (x, y) s =
  nth out (rect (x %/ h * h + y %/ w) s) (x %% h * w + y %% w).
Proof.
move=> Hs xLhw yLhw.
have hw_pos : 0 < hw by apply: leq_ltn_trans xLhw.
have h_pos := h_pos xLhw; have w_pos := w_pos xLhw.
have x_d_h := hw_divh xLhw; have x_m_h := hw_modh xLhw.
have y_d_w := hw_divw yLhw; have y_m_w := hw_modw yLhw.
rewrite nth_take_and_drop.
- rewrite nth_drop /get /pos2n /= !divnMDl // !modnMDl.
  rewrite modn_small // [(y  %/ w)%/ h]divn_small // addn0.
  rewrite [(_  %% _)%/ _]divn_small // addn0.
  rewrite modn_mod [x in LHS](divn_eq _ h) [y in LHS](divn_eq _ w).
  congr nth; lia.
- by rewrite w_pos -[w]mul1n leq_mul2r eqn0Ngt w_pos.
- by rewrite hw_modwMDmod.
rewrite modnMDl divnMDl // modn_small // [(_ %/ _) %/ h]divn_small //.
rewrite addn0 size_drop Hs.
rewrite /hw in hw_pos xLhw yLhw *; nia.
Qed.

Lemma get_rect_rev i j s :
  size s = hw * hw -> i < hw -> j < hw -> 
  get (j %/ h * h + i %/ w, j %% h * w + i %% w) s = 
  nth  out (rect j s) i.
Proof.
move=> Hs iLhw jLhw.
have hw_pos : 0 < hw by apply: leq_ltn_trans iLhw.
have h_pos := h_pos iLhw; have w_pos := w_pos iLhw.
have j_d_h := hw_divh jLhw; have i_m_h := hw_modh jLhw.
have i_d_w := hw_divw iLhw; have i_m_w := hw_modw iLhw.
rewrite get_rect ?hw_MwD ?hw_MhD //.
rewrite !divnMDl // !modnMDl; congr (nth _ (rect _ _) _).
  by rewrite (divn_small i_d_w) (divn_small i_m_w) !addn0 -divn_eq.
by rewrite modn_mod (modn_small i_d_w) -divn_eq.
Qed.

Lemma valid_get_rect_rev i1 i2 j1 j2 :
  i1 < h -> i2 < w -> j1 < w -> j2 < h -> valid_pos (j1 * h + i1, j2 * w + i2).
Proof.
by move=> i1Lh i2Lw j1Lw j2Lh; rewrite /valid_pos /= hw_MhD // hw_MwD.
Qed.

Lemma size_rect i s :
  i < hw -> size s = hw * hw -> size (rect i s) = hw.
Proof.
rewrite /hw => iLhw Hs.
have h_pos := h_pos iLhw; have w_pos := w_pos iLhw.
have i_d_h := hw_divh iLhw; have i_m_h := hw_modh iLhw.
by rewrite size_take_and_drop // size_drop Hs /hw; nia.
Qed.

(******************************************************************************)
(*    Sudoku                                                                  *)
(******************************************************************************)


(* To be a sudoku, the seq should be of the proper hw, rows, columns and      *)
(* subrectangle should be a permutation of the reference seq                  *)
Definition sudoku s :=
  [&& 
     size s == hw * hw,
     [forall i : 'I_hw, perm_eq (row i s) sref],
     [forall i : 'I_hw, perm_eq (column i s) sref] &
     [forall i : 'I_hw, perm_eq (rect i s) sref]].

Lemma sudokuP s :
  reflect 
  [/\
     size s = hw * hw,
     forall i, i < hw -> perm_eq (row i s) sref,
     forall i, i < hw -> perm_eq (column i s) sref &
     forall i, i < hw -> perm_eq (rect i s) sref]
  (sudoku s).
Proof.
apply: (iffP and4P) => [] [H1 H2 H3 H4]; split; auto.
- by apply/eqP.
- by move=> i iLhw; have /forallP := H2 => /(_ (Ordinal iLhw)).
- by move=> i iLhw; have /forallP := H3 => /(_ (Ordinal iLhw)).
- by move=> i iLhw; have /forallP := H4 => /(_ (Ordinal iLhw)).
- by apply/eqP.
- by apply/forallP => i; apply H2.
- by apply/forallP => i; apply H3.
by apply/forallP => i; apply H4.
Qed.

(******************************************************************************)
(*    Literal, state                                                          *)
(******************************************************************************)

(* A literal is composed of two coordinates and a value *)
Definition lit := (pos * nat)%type.

Definition valid_lit l := (l.2 \in sref) && valid_pos l.1.


(* A state is a list of an ordered of positions with their possible value *)
Definition state := seq (nat * pos * seq bool).
Definition rank_val v := count (fun x => x == true) v.

(* Generate the state that all cells contains a value
  in the reference sequence
*)

Definition init_state : state :=
  let v := nseq hw true in 
  let v1 := false :: v in
  let n := rank_val v in 
  [seq (n, p, v1) | p <- cross2].

Implicit Type st : state.

Fixpoint add_state n p s st := 
  if st is ((n1, p1, s1) as t) :: st1 then 
     if n <= n1 then (n, p, s) :: st else 
     t :: add_state n p s st1
  else [:: (n, p, s)].

Definition bcons b s :=  
  if b then b :: s else if s is _ :: _ then b :: s else [::].

Fixpoint rm_val n (s : seq bool) {struct s} := 
  if s is b :: s1 then 
    if n is n1.+1 then bcons b (rm_val n1 s1) else bcons false s1
  else [::].

Definition in_val i s := nth false s i.

Lemma in_val_nil i : in_val i [::] = false.
Proof. by rewrite /in_val nth_nil. Qed.

Lemma in_val_rm_val i j s : 
  in_val i (rm_val j s) = (i != j) && in_val i s.
Proof.
elim: s i j => [[|i] [|j]|b s1 IH [|i] [|j]] //=; first by rewrite andbF.
- by case: s1 IH.
- by case: b => //; case: rm_val.
- by case: s1 IH => [|b1 s1] IH //=; rewrite in_val_nil.
case: rm_val (IH i j) => [|b2 s2] /=.
  by case: b => /=; rewrite in_val_nil; case: in_val; rewrite (andbT, andbF).
by case: b.
Qed.

Fixpoint update_state p i st := 
  if st is ((n1, p1, s1) as t) :: st1 then 
    if p == p1 then 
      let s2 := rm_val i s1 in
      add_state (rank_val s2) p s2 st1 else  
      add_state n1 p1 s1 (update_state p i st1)
  else [::].

(* list of all values *)
Definition sval st := [seq (let: (_,_,v) := i in v) | i <- st ].

(* list of all positions *)
Definition spos st := [seq (let: (_,p,_) := i in p) | i <- st ].

Lemma perm_spos_add n p i st : 
  perm_eq (spos (add_state n p i st)) (p :: spos st).
Proof.
elim: st => //= [] [[n1 p1] i1] st IH.
case: leqP => //= _.
by rewrite perm_sym -perm_rcons /= perm_cons perm_rcons perm_sym.
Qed.

Lemma perm_spos_update p i st :
  perm_eq (spos (update_state p i st)) (spos st).
Proof.
elim: st => //= [] [[n1 p1] i1] st IH.
case: eqP => /= [<-|_]; first by apply: perm_spos_add.
apply: perm_trans (perm_spos_add _ _ _ _) _.
by rewrite perm_cons.
Qed.

Lemma ulist_update p z st : 
  uniq (spos st) -> uniq (spos (update_state p z st)).
Proof.
by move=> Hu; rewrite (perm_uniq (perm_spos_update _ _ _)).
Qed.

Lemma spos_init_state : spos init_state = cross2.
Proof. by rewrite /spos -map_comp /=; elim: cross2 => //= a st ->. Qed.

Definition in_state p i st := 
  has (fun v => let: (_, p1, v1) := v in (p == p1) && (in_val i v1)) st.

Lemma in_state_add p1 p2 i1 n2 v2 st :
  in_state p1 i1 (add_state n2 p2 v2 st) =
    ((p1 == p2) && (in_val i1 v2)) || in_state p1 i1 st.
Proof.
elim: st => //= [] [[n3 p3] v3] st IH.
case: leqP => Ln2n3 //=.
rewrite IH.
by do 2 case: eqP => //=; do 2 case: in_val.
Qed.

Lemma notin_spos p i st : p \notin spos st -> in_state p i st = false.
Proof.
elim: st => //= [] [[n1 p1] v1] st IH.
by rewrite in_cons !negb_or => /andP[/negPf-> /IH->].
Qed.

Lemma in_state_spos p i st : in_state p i st -> p \in spos st.
Proof.
by case: (_ \in _) (@notin_spos p i st) => // /(_ isT)->.
Qed.

Lemma in_state_update p1 p2 i1 i2 st :
  uniq (spos st) ->
  in_state p1 i1 (update_state p2 i2 st) =
    ((p1 != p2) || (i1 != i2)) && in_state p1 i1 st.
Proof.
elim: st => /= [|[[n3 p3] v3] st IH /andP[p3D p3U]]; first by rewrite andbF.
case: eqP p3D => [<-|p1Dp3] p3D /=.
  rewrite in_state_add in_val_rm_val.
  by (do 2 (case: eqP => //=)) => _ ->; rewrite notin_spos.
rewrite in_state_add IH //.
do 3 case: eqP => //=.
by move=> _ p2E p3E; case: p1Dp3; rewrite -p2E.
Qed.

Lemma in_state_init n p v : 
  (n, p, v) \in init_state =
  [&& n == rank_val (nseq hw true),
      valid_pos p &
      v == false :: nseq hw true].
Proof.
apply/mapP/idP => [[[x y]] Hc [<- -> <-] |/and3P[/eqP<- Hc /eqP<-]].
  by rewrite  -mem_cross2 Hc !eqxx.
by exists p; rewrite ?mem_cross2.
Qed.

Lemma in_state_init_state p z : 
  valid_pos p -> z \in sref -> in_state p z init_state.
Proof.
move=> Hp Hz; apply/hasP.
exists (rank_val (nseq hw true), p, false :: nseq hw true).
  by rewrite in_state_init !eqxx Hp.
rewrite eqxx; rewrite mem_iota in Hz.
case: z Hz => //= z; rewrite add1n ltnS => zLhw.
by rewrite /in_val nth_nseq zLhw.
Qed.


Definition valid_state st := 
  [/\ uniq (spos st), 
  forall p, p \in spos st -> valid_pos p &
  forall p z, in_state p z st -> z \in sref].

Lemma valid_state_update p z (st : state) :
  valid_state st -> valid_state (update_state p z st).
Proof.
move=> [Hu Hv Hw]; split.
  by rewrite (perm_uniq (perm_spos_update _ _ _)) Hu /=.
- move=> p1 Hp1; apply: Hv.
  by rewrite (perm_mem (perm_spos_update _ _ _)) in Hp1.
move=> p1 z1.
by rewrite in_state_update // => /andP[_ /Hw].
Qed.

Lemma in_state_cons n p v z st : valid_state ((n, p, v) :: st) ->
  in_state p z ((n, p, v) :: st) = in_val z v.
Proof.
rewrite /= eqxx /=.
move=> Hv; case: in_val => //=.
apply/negP.
have [/= /andP[Hv1 _] _ _] := Hv.
elim: st {Hv}Hv1 => //= [] [[n1 p1] v1] st IH.
by rewrite inE negb_or; case: eqP.
Qed.


Definition rm_state p st := 
  [seq i <- st | let: (_, p1, v1) := i in (p != p1)].

Lemma spos_rm_state st p p1 :
  p1 \in spos (rm_state p st) = (p1 != p) && (p1 \in spos st).
Proof.
case: p => x y; elim: st => /= [|[[n [x2 y2]] v] st IH].
  by rewrite in_nil andbF.
case: eqP => /= [[<- <-]|]; rewrite !in_cons IH; first by case: eqP.
by do 2 case: eqP => //= ->.
Qed.

Lemma subseq_rm_state p st : subseq (rm_state p st) st.
Proof. by apply: filter_subseq. Qed.

Lemma in_state_rm p1 p2 z st : 
  in_state p1 z (rm_state p2 st) -> in_state p1 z st.
Proof.
elim: st => //= [] [[n p3] v] st IH.
case: eqP => //= [<- /IH->|_]; first by rewrite orbT.
by case/orP => [->//|/IH->]; rewrite orbT.
Qed.

Lemma notin_state_rm p1 p2 z st : 
  p1 != p2 -> ~~ in_state p1 z (rm_state p2 st) -> ~~ in_state p1 z st.
Proof.
move=> p1Dp2.
elim: st => //= [] [[n p3] v] st IH.
case: eqP => /= [<- /IH H1|_ ].
  by rewrite negb_or negb_and p1Dp2 H1.
by rewrite !negb_or /= => /andP[->].
Qed.

Lemma valid_state_rm_state p st :
  valid_state st -> valid_state (rm_state p st).
Proof.
move=> [Hp Hs Ht]; split.
- apply: subseq_uniq Hp.
  by apply: map_subseq (subseq_rm_state _ _).
- move=> p1; rewrite spos_rm_state => /andP[_].
  by apply: Hs.
by move=> p1 z /in_state_rm/Ht.
Qed.

Lemma rm_state_cons n p v st : valid_state ((n, p, v) :: st) ->
  rm_state p ((n, p, v) :: st) = st.
Proof.
rewrite /= eqxx /=.
move=> Hv; have [/= /andP[Hv1 _] _ _] := Hv.
elim: st {Hv}Hv1 => //= [] [[n1 p1] v1] st IH.
rewrite inE negb_or; case: eqP => //= ? ?.
by rewrite IH.
Qed.


(* Given a literal that we know that holds generate the seq of literals
   that we know cannot hold *)
Definition update_anti_literals (p : pos) z (st : state) : state :=
  let: (x, y) := p in
  let st1 := foldr (fun x1 st => if x == x1 then st else
                                 update_state (x1, y) z st) st indexes in
  let st2 := foldr (fun y1 st => if y == y1 then st else
                                 update_state (x, y1) z st) st1 indexes in
  let x1 := x %/ h * h in
  let y1 := y %/ w * w in
  let st3 := foldr (fun p1 st => if p == shift p1 x1 y1 then st else
                                 update_state (shift p1 x1 y1) z st) st2 cross in
  st3.

Definition anti_literals (l : lit) : seq lit :=
  let: ((x, y), z) := l in 
  let rx1 := x %/ h * h in
  let ry1 := y %/ w * w in
  [seq ((x, y1), z) | y1 <- indexes & y != y1 ] ++ 
  [seq ((x1, y), z) | x1 <- indexes & x != x1 ] ++ 
  [seq (shift p rx1 ry1, z) | p <- cross & (x, y) != shift p rx1 ry1].

Lemma eqz_anti_literals p1 p2 z1 z2 :
  (p1, z1) \in anti_literals (p2, z2) -> z1 = z2.
Proof. by case: p2 => x2 y2; rewrite !mem_cat => /or3P[] /mapP[x _] []. Qed.

Lemma valid_pos_anti_literals p1 p2 z1 z2 :
  (p1, z1) \in anti_literals (p2, z2) -> valid_pos p2 -> valid_pos p1.
Proof.
case: p1 => x1 y1;  case: p2 => x2 y2.
rewrite !mem_cat => /or3P[] /mapP[x];
   rewrite mem_filter ?mem_iota ?crossP ?add0n /= => 
     /andP[Hd Hhw] [-> -> _] /andP[/= x2Lhw y2Lhw]; rewrite /valid_pos /=.
- by rewrite x2Lhw Hhw.
- by rewrite Hhw y2Lhw.
have /andP[x1Lh x2Lw] := Hhw.
by rewrite hw_divhMD // hw_divwMD.
Qed.

Lemma anti_literals_swap p1 p2 z1 z2 :
  valid_pos p1 -> (p2, z2) \in anti_literals (p1, z1) -> 
  (p1, z1) \in anti_literals (p2, z2).  
Proof.
case: p1 => x1 y1; case: p2 => x2 y2 => /andP[/= x1Lhw y1Lhw].
rewrite !mem_cat => /or3P[] /mapP[x];
   rewrite mem_filter ?mem_iota ?crossP ?add0n => 
     /andP[Hd Hhw] [-> -> ->].
- apply/or3P; apply: Or31.
  by rewrite map_f // mem_filter // eq_sym Hd mem_iota.
- apply/or3P; apply: Or32.
  by rewrite map_f // mem_filter // eq_sym Hd mem_iota.
apply/or3P; apply: Or33.
have h_pos := h_pos x1Lhw; have w_pos := w_pos x1Lhw.
have /andP[x1Lh x2Lw] := Hhw.
rewrite !divnMDl // (divn_small x1Lh) (divn_small x2Lw) !addn0.
have ->: (x1, y1) = shift (x1 %% h, y1 %% w) (x1 %/ h * h) (y1 %/ w * w).
  by rewrite /shift /= -!divn_eq.
rewrite map_f // mem_filter crossP /= hw_modh // hw_modw // !andbT.
rewrite /shift /= xpair_eqE {1}(divn_eq x1 h)  
        {1}(divn_eq y1 w) !eqn_add2l eq_sym [_ == x.2]eq_sym in Hd.
by rewrite /shift /= xpair_eqE /= !eqn_add2l.
Qed.

Lemma anti_literals_nswap p1 p2 z1 z2 :
  valid_pos p2 -> (p2, z2) \notin anti_literals (p1, z1) -> 
  (p1, z1) \notin anti_literals (p2, z2).  
Proof. by move=> Hp2; apply/contra/anti_literals_swap. Qed.

Lemma notin_anti_literals l : l \notin anti_literals l.
Proof.
case: l => [] [x y] z.
rewrite !mem_cat !negb_or; apply/and3P; split; apply/negP=> /mapP.
- by move=> [y1 Hy1 [yE]]; rewrite yE mem_filter eqxx in Hy1.
- by move=> [x1 Hx1 [xE]]; rewrite xE mem_filter eqxx in Hx1.
- move=> [[x2 y2] Hxy2 [xE yE]].
by rewrite mem_filter xpair_eqE /= -xE -yE !eqxx in Hxy2.
Qed.

Lemma anti_literals_valid_lit l :
  valid_lit l -> all valid_lit (anti_literals l).
Proof.
case: l => [] [x y] z /andP[/= Hz /andP[/= Hx Hy]]; rewrite !all_cat.
apply/and3P; split; apply/allP => i /mapP [j]; 
    rewrite mem_filter => /andP[Hd Hj] ->; apply/andP; split => //=.
- by apply/andP; split=> //=; rewrite mem_iota in Hj.
- by apply/andP; split=> //=; rewrite mem_iota in Hj.
rewrite crossP in Hj; case/andP: Hj => Hj1 Hj2.
apply: valid_get_rect_rev=> //.
  by rewrite ltn_divLR 1?mulnC ?Hx //; lia.
rewrite ltn_divLR ?Hy //; lia.
Qed.

Lemma valid_state_fold (A : Type) (st : state) (s : seq A)  h1 g1 z :
  valid_state st -> 
  valid_state
       (foldr
          (fun (x1 : A) st0 =>
          if h1 x1 then st0 else update_state (g1 x1) z st0) st s).
Proof.
elim: s st => [|x s IH] st Hu //=.
case: (h1 _) => //=; first by apply: IH.
by apply/valid_state_update/IH.
Qed.

Lemma valid_state_update_anti_literals p z (st : state) :
  valid_state st -> valid_state (update_anti_literals p z (rm_state p st)).
Proof.
case: p => x y Hv.
by do 3 apply: valid_state_fold; apply: valid_state_rm_state.
Qed.

Lemma uniq_spos_fold (A : Type) (st : state) (s : seq A)  h1 g1  z :
  uniq (spos st) ->
  uniq
    (spos
       (foldr
          (fun (x1 : A) st0 =>
          if h1 x1 then st0 else update_state (g1 x1) z st0) st s)).
Proof.
elim: s st => [|x s IH] st Hu //=.
case: (h1 _) => //=; first by apply: IH.
by apply/ulist_update/IH.
Qed.

Lemma update_fold (A : Type) (st : state) (s : seq A)  h1 g1  z (p1 : pos) z1 : 
  uniq (spos st) ->
  in_state p1 z1
  (foldr (fun x1 st => if h1 x1 then st else
                      update_state (g1 x1) z st) st s)  =
  ((p1, z1) \notin [seq (g1 x1, z) | x1 <- s & ~~ h1 x1]) && 
   (in_state p1 z1 st).
Proof.
move=> Hu.
elim: s => //= u s IH; case: (h1 _) => /=.
rewrite IH //.
rewrite in_state_update.
rewrite in_cons negb_or xpair_eqE negb_and IH // andbA //.
by apply: uniq_spos_fold.
Qed.


Lemma in_state_update_anti p1 p2 z1 z2 st :
  uniq (spos st) ->
  in_state p1 z1 (update_anti_literals p2 z2 st) =
  ((p1, z1) \notin (anti_literals (p2,z2))) && in_state p1 z1 st.
Proof.
move=> Hu.
case: p2 => x2 y2 => /=.
rewrite !update_fold //.
- by rewrite !mem_cat !negb_or; do 3 case: (_ \in _).
- by apply: uniq_spos_fold.
- by apply/uniq_spos_fold/uniq_spos_fold.
Qed.

Lemma perm_spos_fold (A : Type) (st : state) (s : seq A)  h1 g1 z :
  perm_eq 
      (spos (foldr
          (fun (x1 : A) st0 =>
           if h1 x1 then st0 else update_state (g1 x1) z st0) st s)) 
      (spos st).
Proof.
elim: s st => //= x s IH st.
case: (h1 _); first by rewrite IH.
by apply: perm_trans (perm_spos_update _ _ _) (IH _).
Qed.

Lemma perm_spos_update_anti_literals p z (st : state) :
  perm_eq (spos (update_anti_literals p z st)) (spos st).
Proof.
by case: p => x y; do 3 apply: perm_trans (perm_spos_fold _ _ _ _ _) _.
Qed.

Lemma size_update_anti_literals p k st : 
  size (update_anti_literals p k st) = size st.
Proof.
rewrite -(size_map ((fun '(y, _) => let '(_, p) := y in p))) 
        -[map _ _]/(spos _).
by rewrite (perm_size (perm_spos_update_anti_literals _ _ _)) size_map.
Qed.

(* Auxiliary function that updates the state st with
   the seq s, interpreting the first element of s as in position p
   the update is performed only for the elements of s that are in sref
 *)

Fixpoint gen_init_state_aux (s : seq nat) (p : pos) (st : state)
    {struct s} : option state :=
  match s with
  | nil => some st
  | a :: s1 =>
    let p1 := next p in
    if (a \in sref) then
      if in_state p a st then
        let st1 := rm_state p st in 
        gen_init_state_aux s1 p1 (update_anti_literals p a st1) else
      None
    else gen_init_state_aux s1 p1 st
  end.

(* Generate the state relative to a seq s *)
Definition gen_init_state s := gen_init_state_aux s (0, 0) init_state.

(******************************************************************************)
(*    Algorithm that finds a solution                                         *)
(******************************************************************************)

(* Try to satisfy one of the literal of seq l calling after
   the continuation f
 *)
Fixpoint try_one (bs : seq bool) (p : pos) (z : nat) (s : seq nat)
         (st : state)
         (f: seq nat -> state -> option (seq nat))
         {struct bs}:
  option (seq nat) :=
  if bs is b :: bs1 then 
    if b then 
      let s1 := update p z s in
      let st1 := update_anti_literals p z st in
      if f s1 st1 is Some c1 then Some c1 else try_one bs1 p z.+1 s st f
     else try_one bs1 p z.+1 s st f
  else None. 

(* An auxiliary function to find a solution by iteratively trying
   to satisfy the position in state
 *)
Fixpoint find_one_aux (n : state) (s : seq nat) (st : state) {struct n} :
    option (seq nat) :=
  if st is (_, p, vs) :: st1 then
    if n is _ :: n1 then 
      try_one (behead vs) p 1 s st1 (find_one_aux n1) 
    else None 
  else Some s. 

(* Find one solution that refines the state s *)
Definition find_one s := 
  if gen_init_state s is Some st then
    find_one_aux st s st 
  else None.

(******************************************************************************)
(*    Algorithm that finds all solutions                                      *)
(******************************************************************************)


(** The merge for the sudoku (* we should use lexico from order *) **)
Fixpoint seq_leqn s1 s2 := 
  if s1 is a :: s3 then 
    if s2 is b :: s4 then (a <= b) && seq_leqn s3 s4 else false 
  else true.

Lemma seq_leqn_refl : reflexive seq_leqn.
Proof. by elim=> //= a l ->; rewrite leqnn. Qed.

Lemma seq_leqn_trans : transitive seq_leqn.
Proof.
elim=> [[]|a s1 IH [|b s2] [|c s3]] //= /andP[Ha Hs1] /andP[Hb Hs2].
by rewrite (leq_trans Ha) // IH.
Qed.

Lemma seq_leqn_anti s1 s2 : seq_leqn s1 s2 -> seq_leqn s2 s1 -> s1 = s2.
Proof.
elim: s1 s2 => [[]|a s1 IH [|b s2]] //= /andP[Ha Hs1] /andP[Hb Hs2].
by rewrite (IH s2) //; case: ltngtP Ha Hb => // ->.
Qed.

Fixpoint insert_sudoku s ls := 
  if ls is s1 :: ls1 then 
    if seq_leqn s s1 then 
      if seq_leqn s1 s then ls else s :: ls 
    else s1 :: insert_sudoku s ls1
  else [::s].

Lemma mem_insert_sudoku s ls : insert_sudoku s ls =i (s :: ls).
Proof.
elim: ls => //= s1 ls IH.
case: seq_leqn (@seq_leqn_anti s s1) => [|_ i].
  by case: seq_leqn => [->// i|_ i]; rewrite !in_cons; case: eqP.
by rewrite !in_cons IH; do 2 case: eqP => //=.
Qed.

Definition merge_sudoku ls1 ls2 := foldr insert_sudoku ls1 ls2.

Lemma mem_merge_sudoku ls1 ls2 : merge_sudoku ls1 ls2 =i (ls1 ++ ls2).
Proof.
elim: ls2 ls1 => /= [[|a ls1]|a ls2 IH ls1 i] //=; first by rewrite cats0.
by rewrite mem_insert_sudoku !(mem_cat, in_cons, IH); case: eqP => //; 
   case: (_ \in _).
Qed.

(* Find all the literals of seq l that can be satisfied calling after
   the continuation f
 *)
Fixpoint try_all (bs : seq bool) (p : pos) (z : nat) (s : seq nat) (st : state)
                 (f : seq nat -> state -> seq (seq nat)) {struct bs} :
   seq (seq nat) :=
if bs is b :: bs1 then 
  if b then 
    let s1 := update p z s in
    let st1 := update_anti_literals p z st in
    merge_sudoku (f s1 st1) (try_all bs1 p z.+1 s st f)
  else try_all bs1 p z.+1 s st f
else [::].

(* An auxiliary function to find all solutions by iteratively trying
   to satisfy the first clause of the seq of clauses c
 *)
Fixpoint find_all_aux (n : state) (s : seq nat) (st : state) {struct n}:
  seq (seq nat) :=
  if st is (_, p, bs) :: st1 then 
    if n is _ :: n1 then try_all (behead bs) p 1 s st1 (find_all_aux n1)
    else [::]
  else [::s].

(* Find all solutions that refines the state s *)
Definition find_all s := 
  if gen_init_state s is Some st then find_all_aux st s st else [::].

(******************************************************************************)
(*  Algorithm that finds one solution and insures that it is unique           *)
(******************************************************************************)

Inductive jRes : Set := jNone | jOne (_ : seq nat) | jMore (_ _ : seq nat).

Fixpoint try_just_one (bs : seq bool) (p : pos) (z : nat)
                      (s : seq nat) (st : state)
    (f : seq nat -> state -> jRes) : jRes :=
  if bs is b :: bs1 then
    if b then  
      let s1 := update p z s in
      let st1 := update_anti_literals p z st in
      match f s1 st1 with
      | jNone => try_just_one bs1 p z.+1 s st f
      | jOne s2 => 
        match try_just_one bs1 p z.+1 s st f with
        | jNone => jOne s2
        | jOne s3 => if s2 == s3 then jOne s2 else jMore s2 s3
        | jMore s1 s2 => jMore s1 s2
        end
      | jMore s1 s2 => jMore s1 s2
      end
    else try_just_one bs1 p z.+1 s st f
  else jNone.

(* An auxiliary function to find a solution by iteratively trying
   to satisfy the first clause of the seq of clauses c
 *)
Fixpoint find_just_one_aux (n : state) (s : seq nat) (st : state) : jRes :=
if st is (_, p, bs) :: st1 then 
  if n is _ :: n1 then try_just_one (behead bs) p 1 s st1 (find_just_one_aux n1) 
  else jNone
else jOne s.

(* Find one solution that refines the state s *)
Definition find_just_one s :=
  if gen_init_state s is Some st then find_just_one_aux st s st else jNone.

Lemma sudoku_def s :
  reflect 
    [/\ size s = hw * hw,
        forall p, valid_pos p -> get p s \in sref & 
        forall p1 p2 z, valid_pos p1 -> 
          (p2, z) \in anti_literals (p1, get p1 s) -> get p2 s != z]
  (sudoku s).
Proof.
apply: (iffP and4P) => [[/eqP Hs /forallP Hr /forallP Hc /forallP Hre]|
                        [Hs Hv Ha]]; split => //=.
- move=> [x y] /andP[/= Hx Hy].
  by rewrite -(perm_mem (Hr (Ordinal Hx))) /= get_row // mem_nth // size_row.
- move=> [x1 y1] [x2 y2] z /andP[/= x1Lhw y1Lhw].
  have h_pos := h_pos x1Lhw; have w_pos := w_pos x1Lhw.
  rewrite !mem_cat => /or3P[] /mapP[/= z1];
      rewrite mem_filter => /andP[y1Dz1 z1I] [-> -> ->].    
  + have z1Lhw : z1 < hw by rewrite mem_iota in z1I.
    rewrite !get_row //.
    apply: contra y1Dz1 => /eqP Hnth; apply/eqP.
    have /uniqP : uniq (row x1 s).  
      by rewrite (perm_uniq (Hr (Ordinal x1Lhw))) sref_uniq.
    by move/(_ out); apply; rewrite -?topredE /= ?size_row.
  + have z1Lhw : z1 < hw by rewrite mem_iota in z1I.
    rewrite !get_column //.
    apply: contra y1Dz1 => /eqP Hnth; apply/eqP.
    have /uniqP : uniq (column y1 s).  
      by rewrite (perm_uniq (Hc (Ordinal y1Lhw))) sref_uniq.
    by move/(_ out); apply; rewrite -?topredE /= ?size_column.
  rewrite crossP in z1I; have /andP[Hz11 Hz12] := z1I.
  rewrite !get_rect // ?hw_divhMD  ?hw_divwMD //.
  rewrite !divnMDl // !modnMDl // (divn_small Hz11) addn0.
  rewrite (divn_small Hz12) addn0.
  rewrite (modn_small Hz11) (modn_small Hz12).
  case: z1 y1Dz1 {z1I}Hz11 Hz12 => x3 y3 /= y1Dz1 x3Lh y3Lw.
  apply: contra y1Dz1 => /eqP Hnth; apply/eqP.
  suff ->: (x3, y3) = (x1 %% h, y1 %% w) by rewrite /shift /= -!divn_eq.
  suff He: x3 * w + y3 = x1 %% h * w + y1 %% w.
    rewrite -[x3]addn0 -(divn_small y3Lw) -divnMDl // He divnMDl // 
            divn_small ?ltn_mod // addn0.
    by rewrite -(modn_small y3Lw) -(modnMDl x3 y3) He modnMDl modn_mod.
  have y1wLh := hw_divw y1Lhw.
  have /uniqP : uniq (rect (x1 %/ h * h + y1 %/ w) s).
    by rewrite (perm_uniq (Hre (Ordinal (hw_divhMD x1Lhw y1wLh)))) sref_uniq.
  move/(_ out); apply => //=; rewrite -?topredE /= ?size_rect //.
  + by rewrite /hw; nia.
  + by apply :hw_divhMD.
  + by apply: hw_modwMDmod.
  by apply: hw_divhMD.
- by apply/eqP.
- apply/forallP => /= [] [x xLhw] /=.
  suff Hi : row x s =i sref.
    apply: uniq_perm sref_uniq _ => //.
    by rewrite (eq_uniq _ Hi) ?sref_uniq // size_row // size_sref.
  case (@uniq_min_size _ (row x s) sref) => //.
  + apply/(uniqP out) => y1 y2.
    rewrite -?topredE /= size_row // => y1Lhw y2Lhw.
    rewrite -!get_row //; case: (y1 =P y2) => // /eqP y1Dy2 Hg.
    have [] := negP (Ha (x, y1) (x, y2) (get (x, y1) s) _ _); last by apply/eqP.
      by rewrite /valid_pos /= xLhw.
    rewrite mem_cat; apply/orP; left.
    apply: map_f.
    by rewrite mem_filter y1Dy2 mem_iota.
  + move=> i /(nthP out)[y]; rewrite size_row // => yLhw.
    rewrite -get_row // => <-.
    by apply: Hv; rewrite /valid_pos /= xLhw.
  by rewrite size_sref size_row.
- apply/forallP => /= [] [y yLhw] /=.
  suff Hi : column y s =i sref.
    apply: uniq_perm sref_uniq _ => //.
    by rewrite (eq_uniq _ Hi) ?sref_uniq // size_column // size_sref.
  case (@uniq_min_size _ (column y s) sref) => //.
  + apply/(uniqP out) => x1 x2.
    rewrite -?topredE /= size_column // => x1Lhw x2Lhw.
    rewrite -!get_column //; case: (x1 =P x2) => // /eqP x1Dx2 Hg.
    have [] := negP (Ha (x1, y) (x2, y) (get (x1, y) s) _ _); last by apply/eqP.
      by rewrite /valid_pos /= x1Lhw.
    rewrite !mem_cat; apply/orP; right; apply/orP; left.
    apply: map_f.
    by rewrite mem_filter x1Dx2 mem_iota.
  + move=> i /(nthP out)[x]; rewrite size_column // => xLhw.
    rewrite -get_column // => <-.
    by apply: Hv; rewrite /valid_pos /= xLhw.
  by rewrite size_sref size_column.
apply/forallP => /= [] [i iLhw] /=.
suff Hi : rect i s =i sref.
  apply: uniq_perm sref_uniq _ => //.
  by rewrite (eq_uniq _ Hi) ?sref_uniq // size_rect // size_sref.
have h_pos := h_pos iLhw; have w_pos := w_pos iLhw.
case (@uniq_min_size _ (rect i s) sref) => //.
- apply/(uniqP out) => j1 j2.
  rewrite -?topredE /= size_rect // => j1Lhw j2Lhw.
  rewrite -!get_rect_rev //; case: (j1 =P j2) => // /eqP j1Dj2 Hg.
  set p1 := (_, _) in Hg; set p2 := (_, _) in Hg.
  have [] := negP (Ha p1 p2 (get p1 s) _ _); last by apply/eqP.
    apply/andP; split=> /=; first by rewrite hw_divhMD // hw_divw.
    by apply: hw_modwMDmod.
  rewrite !mem_cat; apply/orP; right; apply/orP; right.
  rewrite !divnMDl // [(_ %/ _) %/ _]divn_small; last by rewrite ltn_divLR.
  rewrite addn0 [(_ %% _) %/ _]divn_small ?ltn_mod // addn0.
  have -> : p2 = shift (j2 %/ w, j2 %% w) (i %/ h * h) (i %% h * w).
    by apply/eqP; rewrite xpair_eqE !eqn_add2l // !eqxx.
  apply: map_f; rewrite mem_filter; apply/andP; split => /=.
    rewrite xpair_eqE /= !eqn_add2l.
    apply: contra j1Dj2 => /andP[/eqP Hj1 /eqP Hj2].
    by rewrite (divn_eq j1 w) Hj1 Hj2 -divn_eq.
  by rewrite crossP /= ltn_mod w_pos hw_divw.
- move=> j /(nthP out)[k]; rewrite size_rect // => kLhw.
  rewrite -get_rect_rev // => <-.
  apply: Hv; apply/andP; split => /=; first by rewrite hw_divhMD // hw_divw.
  by apply: hw_modwMDmod.
by rewrite size_sref size_rect.
Qed.

Lemma sudoku_refine_id s1 s2 : sudoku s1 -> refine s1 s2 -> s1 = s2.
Proof.
move=> Hs /refineP[Hr1 Hr2 Hr3].
apply: (@eq_from_nth _ out) => [|i iLs1]; first by rewrite Hr2.
rewrite Hr1 in iLs1.
rewrite -[i]pos2nK //.
have hw_pos : 0 < hw by case: hw iLs1.
have Hv : valid_pos (i %/ hw, i %% hw).
  by rewrite /valid_pos ltn_divLR ?iLs1 //= ltn_mod.
apply: Hr3 => //.
by have /sudoku_def[_ ->] := Hs.
Qed.


Definition invariant st s :=
  [/\ 
    size s = hw * hw,
    valid_state st,
    forall p, valid_pos p -> (get p s \in sref) = (p \notin spos st),
    forall p1 p2, valid_pos p1 -> valid_pos p2 ->
                  get p1 s \in sref -> get p2 s \in sref ->
                  (p1, get p1 s) \notin anti_literals (p2, get p2 s) &
    (forall p1 p2 z, valid_pos p1 -> valid_pos p2 -> z \in sref ->
              get p2 s \in sref -> in_state p1 z st -> 
              (p1, z) \notin anti_literals (p2, get p2 s)) /\
    forall p1 z1, valid_pos p1 -> z1 \in sref -> get p1 s \notin sref -> 
                ~~ in_state p1 z1 st -> 
                exists p2, [/\ valid_pos p2, get p2 s \in sref & 
                               (p1, z1) \in anti_literals (p2, get p2 s)]].

Lemma invariant_init : invariant init_state init.
Proof.
split.
- by rewrite size_init.
- split; first by rewrite spos_init_state cross2_uniq.
    by move=> p; rewrite spos_init_state mem_cross2.
  move=> p z.
  rewrite /init_state.
  elim: cross2 => //= p1 cross2 IH .
  case/orP => [/andP[_]|]; last first.
    by apply: IH => // p2 Hp2; apply: Hc; rewrite in_cons Hp2 orbT.
  case: (z) => [|z1]; rewrite /in_val //= nth_nseq mem_iota add1n !ltnS /=.
  by case: leqP.
- by move=> p Hp; rewrite (negPf (get_init _)) spos_init_state mem_cross2 Hp.
- by move=> p1 p2;  rewrite (negPf (get_init _)).
split.
  by move=> p1 p2; rewrite (negPf (get_init _)).
by move=> p1 z1 Hp1 Hz1; rewrite in_state_init_state.
Qed.

Lemma invariant_update p z st s :
  invariant st s -> in_state p z st ->
  invariant (update_anti_literals p z (rm_state p st)) (update p z s).
Proof.
move=> [Hs Hpos Hanti Hi [His1 His2]] Hin.
case: (Hpos)=> _ _ /(_ _ _ Hin) => Hz.
case: (Hpos) => _ /(_ _ (in_state_spos Hin)) => Hp.
split.
- by rewrite size_update.
- by apply: valid_state_update_anti_literals.
- move=> p1 Bp1.
  rewrite (perm_mem (perm_spos_update_anti_literals _ _ _)).
  rewrite spos_rm_state.
  case: (p1 =P p) => /= [->|/eqP p1Dp].
    by rewrite update_get.
  by rewrite update_diff_get // Hanti.
move=> p1 p2.
  case: (p1 =P p) => [->|/eqP p1Dp]; case: (p2 =P p) => [->|/eqP p2Dp] Hp1 Hp2.
  - by rewrite !update_get // notin_anti_literals.
  - rewrite update_get // update_diff_get //.
    by move=> Hx Hg2; rewrite His1.
  - rewrite update_get // update_diff_get //.
    move=> Hg1 _; apply: anti_literals_nswap => //.
    by apply: His1.
  by rewrite !update_diff_get //; apply: Hi.
split.
  move=> p1 p2 z1.
  rewrite in_state_update_anti; last first.
    by have [] := valid_state_rm_state p Hpos.
  case: (p2 =P p) => [->|/eqP p2Dp].
    rewrite update_get //.
    by move=> Hp1 Hp2 _ _ /andP[Hna _].
  move=> Hp1 Hp2 Hz1.
  rewrite update_diff_get // => Hg2 /andP[H1 H2].
  apply: His1 => //.
  by apply: in_state_rm H2.
move=> p1 z1 Hp1 Hz1.
case: (p1 =P p) => [->|/eqP p1Dp].
  by rewrite update_get // Hz.
rewrite update_diff_get //.
rewrite in_state_update_anti; last first.
  by have [] := valid_state_rm_state p Hpos.
rewrite negb_and negbK => Hg1 /orP[Han|HNi]; last first.
  case: (His2 p1 z1) => //.
    by apply: notin_state_rm HNi.
  move=> p2 [H1p2 H2p2 H3p2].
  have p2Dp : p2 != p.
    apply/eqP=> p2Ep.
    have : p \in spos st by apply: in_state_spos Hin.
    have := (Hanti p Hp).
    by rewrite -p2Ep H2p2; case: (_ \in _).
  by exists p2; rewrite update_diff_get.
by exists p; rewrite update_get.
Qed.

Lemma invariant_nil s : invariant [::] s -> sudoku s.
Proof.
move=> [Hs Hpos Hanti Hi [His1 His2]].
apply/sudoku_def; split=> //.
move=> p1 p2 z Hv Hz; apply/negP => /eqP Hg.
have : (p1, get p1 s) \notin anti_literals (p2, get p2 s).
  apply: Hi => //.
  - by apply: valid_pos_anti_literals Hz _.
  - by rewrite Hanti.
  by rewrite Hg (eqz_anti_literals Hz) Hanti.
rewrite Hg => /anti_literals_nswap => /(_ Hv).
by case: (_ \in _) Hz.
Qed.

Lemma invariant_refine_update p st s s1 :
  invariant st s -> valid_pos p -> get p s \notin sref ->
  refine s s1 -> sudoku s1 -> in_state p (get p s1) st.
Proof.
move=> [Hs Hpos Hanti Hi [His1 His2]] Hv Hgp /refineP[H1r H2r H3r]
        /sudoku_def[H1su H2su H3su].
case: (boolP (in_state _ _ _)) => // Hz.
case: (His2 p (get p s1)) => // [|p2 [H1p2 H2p2 H3p2]].
  by apply: H2su.
rewrite (H3r p2) // in H3p2.
by have := H3su _ _ _ H1p2 H3p2; rewrite eqxx.
Qed.

Lemma invariant_nil_refine_not_sudoku p st n s s1 :
  invariant ((n, p, [::]) :: st) s -> refine s s1 -> ~~ sudoku s1.
Proof.
move=> Hs Hr; apply/negP=> Hsu.
have [/= /andP[H1vs H2v3] H3vs H4vs] :
  valid_state ((n, p, [::]) :: st) by case: Hs.
have Hp : valid_pos p by apply: H3vs; rewrite /= in_cons eqxx.
have /= : in_state p (get p s1) ((n, p, [::]) :: st).
  apply: invariant_refine_update (Hs) _ _ _ _ => //.
  by case: Hs => _ _ -> //; rewrite in_cons eqxx.
rewrite eqxx /in_val nth_nil /=.
elim: (st) H1vs => //= [] [[n1 p1] v1] st1 IH.
rewrite in_cons negb_or => /andP[/negPf-> Hpp] /=.
by apply: IH.
Qed.

Lemma invariant_equiv st s1 s2 :
  refine s1 s2 -> refine s2 s1 -> invariant st s1 -> invariant st s2.
Proof.
move=> /refineP[Hs1 Hs2 Hg12] /refineP[_ _  Hg21] [H1 H2 H3 H4 [H5 H6]].
split => //.
- move=> p Hv; rewrite -H3 //.
  by apply/idP/idP=> HH; [rewrite -Hg21 | rewrite -Hg12].
- move=> p1 p2 Hp1 Hp2 Hg1 Hg2.
  by rewrite Hg21 // Hg21 // H4 // -Hg21.
split.
  move=> p1 p2 z Hp1 Hp2 Hz Hg1 Hin.
  by rewrite Hg21 // H5 // -Hg21.
move=> p1 z1 Hp1 Hz1 Hg1 Hn.
case: (H6 p1 z1) => //.
  by apply: contra Hg1 => Hgg1; rewrite -Hg12.
move=> p2 [H1p2 H2p2 H3p2].
by exists p2; split=> //; rewrite -Hg12.
Qed.

Lemma gen_init_state_cotrect s :
  size s = hw * hw -> 
  if gen_init_state s is Some st1 then invariant st1 s
  else forall s1, refine s s1 -> ~ sudoku s1.
Proof.
revert s.
rewrite /gen_init_state.
suff H s s1 st p : (s1 != nil -> valid_pos p) -> size s = hw * hw ->
    invariant st (prestrict p s) -> s1 = drop (pos2n p) s ->
    if gen_init_state_aux s1 p st is Some st1 then invariant st1 s
    else forall s1, refine s s1 -> ~ sudoku s1.
  case: (hw =P 0) => [hwE|hwD0].
    rewrite hwE; case=> //=; have := invariant_init.
    by rewrite /init hwE.
  move=> s Hs; apply: H => //.
  - by case: (s) Hs => //= _ s2; rewrite /valid_pos; case: hw.
  - rewrite prestrict_0.
    by rewrite Hs; apply: invariant_init.
  by rewrite drop0.
elim: s1 s st p => /= [|v s1 IH]/= s st p Hp Hs Hin Hd.
  rewrite prestrict_all // in Hin.
  rewrite -subn_eq0; apply/eqP.
  by rewrite -size_drop -Hd.
have Hgv :  get p s = v.
  by rewrite /get -[pos2n p]addn0 -nth_drop -Hd.
have {}Hp := Hp isT.
have Hv : s1 != [::] -> valid_pos (next p).
  case: s1 {IH}Hd => //= v1 s1 Hd _.
  apply: valid_pos_next => //.
  rewrite next_pos -Hs.
  case: leqP => // /drop_oversize.
  by rewrite -add1n -drop_drop -Hd.
have Hdr : s1 = drop (pos2n (next p)) s.
  by rewrite next_pos -add1n -drop_drop -Hd /= drop0.
have [vis|vnis] := boolP (v \in sref); last first.
  apply: IH => //.
  apply: invariant_equiv Hin; apply/refineP; split.
    - by rewrite prestrict_size.
    - by rewrite prestrict_size.
    - move=> p1 Hp1 Hg1.
      case: (leqP (pos2n p) (pos2n p1)) => Lp.
        rewrite prestrict_get_default // in Hg1.
        by case/negP: out_not_in_refl.
      by rewrite !prestrict_get // next_pos (leq_trans Lp).
    - by rewrite prestrict_size.
    - by rewrite prestrict_size.
    move=> p1 Hp1 Hg1.
    case: (leqP (pos2n p1) (pos2n p)) => Lp; last first.
      rewrite prestrict_get_default // in Hg1.
        by case/negP: out_not_in_refl.
      by rewrite next_pos.
    case: ltngtP Lp => // Lp1 .
      by rewrite !prestrict_get // next_pos (leq_trans Lp1).
    rewrite prestrict_get // in Hg1; last first.
      by rewrite next_pos Lp1.
    case/negP: vnis.
    by rewrite /get Lp1 -[pos2n _]addn0 -nth_drop -Hd in Hg1.
have [His|Hnis] := boolP (in_state p v st); last first.
  move=> s2 Hrss2 /sudoku_def[H1su H2su H3su].
  have [_ _ _ _ [_ Hin1]] := Hin.
  case: (Hin1 p v) => // [|p2 [H1p2 H2p2 H3p2]].
    by rewrite prestrict_get_default // out_not_in_refl.
  have Hrps : refine (prestrict p s) s by apply: refine_prestrict.
  case: (get p s2 =P v); [apply/eqP|case=> //].
    apply: H3su (H1p2) _.
    have /refineP[_ _ <-//] := Hrss2.
      by have /refineP[_ _ /(_ p2)<-//] := Hrps.
    by have /refineP[_ _ /(_ p2)<-//] := Hrps.
  have /refineP[_ _ <-//] := Hrss2.
  by rewrite Hgv.
apply: IH => //.
rewrite prestrict_update.
have->: get p s = v.
  by rewrite /get -[pos2n p]addn0 -nth_drop -Hd.
apply: invariant_update => //.
case: leqP => // H.
by rewrite drop_oversize // -ltnS -next_pos // in Hd.
Qed.

(******************************************************************************)
(*    Main theorems about sudoku solvers                                      *)
(******************************************************************************)

Lemma mem_find_all s s1 :
  size s = hw * hw ->
  (refine s s1 && sudoku s1) = (s1 \in find_all s).
Proof.
move=> Hs; rewrite /find_all.
case: gen_init_state (gen_init_state_cotrect Hs) => [|/(_ s1)]; last first.
  by rewrite in_nil ;case: refine => //= /(_ isT); case: sudoku.
move=> st.
elim: st s Hs {1 3 5}st (leqnn (size st)) => /= [|_ n IH] s Hs.
  case=> // _ /invariant_nil Hu.
  rewrite inE; apply/andP/eqP=> [[Hr1 Hs1]|->].
    by apply/sym_equal/sudoku_refine_id.
  by split => //; apply: refine_refl.
case=> [_ /invariant_nil Hu|[[n1 p1] v1] st] /=.
  rewrite inE; apply/andP/eqP=> [[Hr1 Hs1]|->].
    by apply/sym_equal/sudoku_refine_id.
  by split => //; apply: refine_refl.
rewrite ltnS => stLn Hin.
have Hp1 : valid_pos p1.
  have [_ [_ Hin1] _ _ _ _] := Hin.
  by apply: Hin1 => /=; rewrite inE eqxx.
suff : 
  (behead v1) = drop 1 v1 -> 
  (
    refine s s1 -> sudoku s1 -> get p1 s1 >= 1 ->
    s1 \in try_all (behead v1) p1 1 s st (find_all_aux n)
  ) /\ (
    s1 \in try_all (behead v1) p1 1 s st (find_all_aux n) -> 
    refine s s1 /\ sudoku s1
  ).
  rewrite drop1 => /(_ (refl_equal _)) [H1 H2].
  apply/andP/idP=> // [] [H3 H4].
  apply: H1 => //.
  have /sudoku_def[_ H5 _] := H4.
  case: get (H5 _ Hp1) => //=.
  by rewrite mem_iota.
elim: behead 1 => /= [k Hdr|kb bs IH1 k Hdr]; split.
- move=> /refineP[H1rss1 H2rss1 H3rss1] /sudoku_def[H1su H2su H3su] kLg.
  have [p3 [H1p3 H2p3 H3p3]] : exists p3,
         [/\ valid_pos p3, get p3 s \in sref
          & (p1, get p1 s1) \in anti_literals (p3, get p3 s)].
    have [H1 H2 H3 H4 [H5 H6]] := Hin; apply: H6 => //.
    - by apply: H2su.
    - by rewrite H3 //= inE eqxx.
    rewrite in_state_cons; last by case: Hin.
    by rewrite /in_val -(subnK kLg) addnC -nth_drop -Hdr nth_nil.
  rewrite in_nil; rewrite (H3rss1 p3) // in H3p3. 
  by have /eqP[] := (H3su _ _ _ H1p3 H3p3).
- by rewrite in_nil.
- move=> Hrss1 Hsu kLg. 
  case: kb Hdr => Hdr.
    case: ltngtP kLg => // [kLg | kE] _.
      rewrite mem_merge_sudoku mem_cat; apply/orP; right.
      case: (IH1 k.+1) => [|IH11 IH12].
        by rewrite -add1n -drop_drop -Hdr /= drop0.
      by apply: IH11.
    rewrite mem_merge_sudoku mem_cat; apply/orP; left.
    rewrite -IH //.
    - rewrite Hsu andbT.
      apply/refineP; split => //.
      + by rewrite size_update.
      + by case/refineP : Hrss1.
      move=> p2 Hp2.
      case: (p2 =P p1) => [->|/eqP p2Dp1].
        by rewrite update_get.
      rewrite update_diff_get // => HH.
      by have /refineP[_ _ <-] := Hrss1.
    - by rewrite size_update.
    - by rewrite size_update_anti_literals.
    have <- := @rm_state_cons n1 p1 v1 st; last by case: Hin.
    apply: invariant_update => //.
    rewrite in_state_cons //; last by case: Hin.
    by rewrite /in_val -[k]addn0 -nth_drop -Hdr.
  case: (IH1 k.+1) => [|IH11 IH12].
    by rewrite -add1n -drop_drop -Hdr /= drop0.
  apply: IH11 => //.
  case: ltngtP kLg => // kE.
  have /refineP[H1rss1 H2rss1 H3rss1] := Hrss1.
  have /sudoku_def[H1su H2su H3su] := Hsu.  
  have [p3 [H1p3 H2p3 H3p3]] : exists p3,
         [/\ valid_pos p3, get p3 s \in sref
          & (p1, get p1 s1) \in anti_literals (p3, get p3 s)].
    have [H1 H2 H3 H4 [H5 H6]] := Hin; apply: H6 => //.
    - by apply: H2su.
    - by rewrite H3 //= inE eqxx.
    rewrite in_state_cons; last by case: Hin.
    by rewrite /in_val -kE -[k]addn0 -nth_drop -Hdr.
  rewrite (H3rss1 p3) // in H3p3. 
  by have /eqP[] := (H3su _ _ _ H1p3 H3p3).
case: kb Hdr => Hdr.
  rewrite mem_merge_sudoku mem_cat => /orP[].
    rewrite -IH //.
    - move=>/andP[Hr Hu]; split=> //.
      apply: refine_trans Hr.
      apply: refine_update => //.
      have [_  _ Hin1 _ _] := Hin.
      by rewrite Hin1 //= in_cons eqxx.
    - by rewrite size_update.
    - by rewrite size_update_anti_literals.
    have <- := @rm_state_cons n1 p1 v1 st; last by case: Hin.
    apply: invariant_update => //.
    rewrite in_state_cons //; last by case: Hin.
    by rewrite /in_val -[k]addn0 -nth_drop -Hdr.
   case: (IH1 k.+1) => [|IH11 IH12].
    by rewrite -add1n -drop_drop -Hdr /= drop0.
  by apply: IH12.
case: (IH1 k.+1) => [|IH11 IH12].
  by rewrite -add1n -drop_drop -Hdr /= drop0.
by apply: IH12.
Qed.

(* Proof of one_correct vs all_correct                                        *)

Lemma find_one_aux_correct st s st1 :
if find_one_aux st s st1 is Some s1 then
  s1 \in find_all_aux st s st1
else find_all_aux st s st1 == [::].
Proof.
elim: st s st1=> [s [|[[n p] v]]|[[n p] v] st IH s [|[[n1 p1] v1] st1]] //=.
- by rewrite in_cons eqxx.
- by rewrite in_cons eqxx.
elim: behead p1 1 s st1 => //= [] [] bs IH1 p1 k s st1. 
  case: find_one_aux (IH (update p1 k s) (update_anti_literals p1 k st1)).
    by move=> s1 s1If; rewrite mem_merge_sudoku mem_cat s1If.
  move/eqP=> ->.
  case: try_one (IH1 p1 k.+1 s st1) => [s1|/eqP->//].
  by rewrite mem_merge_sudoku => ->.
by apply: IH1.
Qed.

Lemma find_one_correct_aux s :
  size s = hw * hw ->
  if find_one s is Some s1 then s1 \in find_all s else find_all s == [::].
Proof.
move=> Hs; rewrite /find_one /find_all.
case: gen_init_state (gen_init_state_cotrect Hs) => // st _.
apply find_one_aux_correct.
Qed.

Lemma find_one_correct s :
  size s = hw * hw -> 
  if find_one s is Some s1 then refine s s1 /\ sudoku s1
  else forall s1, refine s s1 -> ~ sudoku s1.
Proof.
move=> Hs.
case: find_one (find_one_correct_aux Hs) => [s1|/eqP He s1 Hr Hsu].
  by rewrite -mem_find_all // => /andP[].
have := mem_find_all s1 Hs.
by rewrite Hr Hsu He in_nil.
Qed.

(* Proof of just one_correct vs all_correct                                   *)

Lemma find_just_one_aux_correct st s st1 :
match find_just_one_aux st s st1 with
| jNone => find_all_aux st s st1 = [::]
| jOne s1 => find_all_aux st s st1 = [:: s1]
| jMore s1 s2 =>
    [/\ s1 \in find_all_aux st s st1, s2 \in find_all_aux st s st1 & s1 != s2]
end.
Proof.
elim: st s st1 => [|[[n p] v] st IH] s  [|[[n1 p1] v1] st1] //=.
elim: behead p1 1 s st1 => //= [] [] bs IH1 p1 k s st1. 
  case: find_just_one_aux (IH (update p1 k s) (update_anti_literals p1 k st1)).
  - move=> -> /=.
    case: try_just_one (IH1 p1 k.+1 s st1) => [->//|s1 ->//|].
    by move=> s1 s2; rewrite !mem_merge_sudoku => [] [-> -> ->].
  - move=> s1 ->.
    case: try_just_one (IH1 p1 k.+1 s st1) => [->//|s2 ->|].
      case: eqP => [->/=|/eqP s1Ds2]; first by rewrite seq_leqn_refl.
    by rewrite !mem_merge_sudoku /= !inE !eqxx orbT (negPf s1Ds2).
  - move=> s2 s3; rewrite !mem_merge_sudoku !inE => [] [-> -> ->].
    by rewrite !orbT.
  by move=> s2 s3; rewrite !mem_merge_sudoku !mem_cat => [] [-> -> ->].
  case: find_just_one_aux (IH (update p1 k s) (update_anti_literals p1 k st1)).
    move=> H.
    by case: try_just_one (IH1 p1 k.+1 s st1) => [->|s1 ->|].
  move=> s1 H.
  by case: try_just_one (IH1 p1 k.+1 s st1) => [->//|s2 ->|].
move=> s1 s2 [H1s H2s H3s].
by case: try_just_one (IH1 p1 k.+1 s st1) => [->//|s3 ->|].
Qed.

Lemma find_just_one_correct_aux s :
  size s = hw * hw ->
  match find_just_one s with 
    jNone =>  find_all s = [::]
  | jOne s1 => find_all s =  [:: s1]
  | jMore s1 s2 =>  
      [/\ s1 \in find_all s, s2 \in find_all s & s1 != s2]
  end.
Proof.
move=> Hs; rewrite /find_just_one /find_all.
case: gen_init_state (gen_init_state_cotrect Hs) => // s1 Hs1.
apply: find_just_one_aux_correct.
Qed.

Lemma find_just_one_correct s :
  size s = hw * hw ->
  match find_just_one s with 
    jNone =>  forall s1, refine s s1 -> ~ sudoku s1
  | jOne s1 => [/\ refine s s1, sudoku s1 & 
                   forall s2, refine s s2 -> sudoku s2 -> s1 = s2]
  | jMore s1 s2 => 
    [/\ refine s s1, sudoku s1, refine s s2, sudoku s2 & s1 != s2]
   end.
Proof.
move=> Hs.
case: find_just_one (find_just_one_correct_aux Hs) => [H s1 Hr Hsu||].
- by have := mem_find_all s1 Hs; rewrite Hr Hsu H in_nil.
- move=> s1 He.
  have: s1 \in find_all s by rewrite He in_cons eqxx.
  rewrite -mem_find_all // => /andP[Hs1 Hr1].
  split => // s2 Hs2 Hr2.
  have: s2 \in find_all s by rewrite -mem_find_all // Hs2.
  by rewrite He inE => /eqP.
move=> s1 s2.
rewrite -!mem_find_all // => [] [/andP[H1 H2] /andP[H3 H4] H5].
by split.
Qed.

End sudoku.

(******************************************************************************)
(*       Parser                                                               *)
(******************************************************************************)

Require Import String.
Import Ascii.
Open Scope string_scope.
Definition sp := 32.
Definition nl := 10.
Definition sep := 124.

Definition is_num x := (48 - x) + (x - 57) == 0.
Definition  get_num x :=  x - 48.

Fixpoint mkline s acc {struct s} :=
  if s is String a s1 then
    let n := nat_of_ascii a in
      if n == sp then
        if acc is Some x then mkline s1 (Some (0::x)) else mkline s1 None  
      else  if n == nl then mkline s1 None
      else if n == sep then
        if acc is Some x then app (rev x) (mkline s1 (Some [::]))
        else mkline s1 (Some [::])
      else if is_num n then
        if acc is Some x then mkline s1 (Some ((get_num n)::x))
        else mkline s1 None
      else mkline s1 None
   else [::].

Definition parse p := mkline p None.

(******************************************************************************)
(*       Print                                                                *)
(******************************************************************************)

Fixpoint print_line (n m : nat) (l : list nat) {struct n}:
  string * list nat :=
let v := if (m %| n) then "|"%string else ""%string in
match n, l with
    O  ,    _ => (v, l)
|  n1.+1, (0 :: l1) =>
    let (s1, l2) := print_line n1 m l1 in (append v (append " " s1), l2)
|  n1.+1, (n :: l1) =>
    let (s1, l2) := print_line n1 m l1 in
                 (append v
                  (String (Ascii.ascii_of_nat (n + 48)) s1),
                  l2)
| _,_ => ("error"%string , l)
end.

Fixpoint paux (m n p q : nat) (s: string) (l : list nat) {struct m}:
  string :=
let v := if p %| m then s else ""%string in
append v
(if m is m1.+1 then
    let (s1, l1) := print_line n q l in
      append s1 (String (Ascii.ascii_of_nat 10) (paux m1 n p q s l1))
else ""%string).

Fixpoint print_sep (n: nat): string :=
  if n is n1.+1 then append "-" (print_sep n1) else ""%string.

Definition print n m s :=
  let lf := Ascii.ascii_of_nat 10 in
  let nm := n * m in
  let s1 := (append
               (print_sep (n + nm).+1)
               (String lf ""%string))
 in
  String lf (paux nm nm n m s1 s).

(******************************************************************************)
(*       Test                                                                 *)
(******************************************************************************)

Definition one_solution n m l :=
 match find_one n m l with Some c => print n m c
                          | _ => "No Solution" end.

Definition solutions n m l := size (find_all n m l).

Definition cr := "
".

Definition just_one_solution n m l :=
 match find_just_one n m l with
   jOne c => print n m c
 | jNone => "No Solution"
 | jMore c1 c2 => ("More Than One Solution" ++ cr
                  ++ (print n m c1) ++ cr ++ (print n m c2))%string
 end.

(* Compute all the sudoku 2 x 2 *)
Eval vm_compute in solutions 2 2 (init 2 2).

Definition os s := one_solution 3 3 (parse s).
Definition ns s := solutions 3 3 (parse s).
Definition jos s := just_one_solution 3 3 (parse s).
Definition kos s := gen_init_state 3 3 (parse s).

Time Eval vm_compute in jos
 "
    -------------
    |  8|16 |9  |
    |  4| 5 |2  |
    |97 |  8| 45|
    -------------
    |  5|   |  6|
    |89 |   | 37|
    |1  |   |4  |
    -------------
    |36 |5  | 84|
    |  2| 7 |5  |
    |  7| 49|3  |
    -------------".

Definition l1 := Eval vm_compute in jos
 "
    -------------
    |  8|16 |9  |
    |  4| 5 |2  |
    |97 |  8| 45|
    -------------
    |  5|   |  6|
    |89 |   | 37|
    |1  |   |4  |
    -------------
    |36 |5  | 84|
    |  2| 7 |5  |
    |  7| 49|3  |
    -------------".



Time Eval vm_compute in jos
 "
    -------------
    |  6|98 |2  |
    |   |   |   |
    |1 7| 43|8 9|
    -------------
    |  2|   |  1|
    |5 3|   |4 7|
    |9  |   |6  |
    -------------
    |2 8|13 |9 5|
    |   |   |   |
    |  4| 78|1  |
    -------------".

Let ppf n m := one_solution n m (init n m).

(* Find a solution for 1 x 1 *)
Time Eval compute in (ppf 1 1).

(* Find a solution for 2 x 1 *)
Time Eval vm_compute in ppf 2 1.

(* Find a solution for 2 x 2 *)
Time Eval vm_compute in ppf 2 2.

(* Find a solution for 3 x 2 *)
Time Eval vm_compute in ppf 3 2.

(* Find a solution for 3 x 3 *)
Time Eval vm_compute in ppf 3 3.

(* A problem with more than one solution *)
Time Eval vm_compute in jos
"
    -------------
    |   |9  |  1|
    |   | 4 | 2 |
    | 8 | 7 |  6|
    -------------
    |2 1|4  |   |
    |   |6  |   |
    |3  |  1|6 8|
    -------------
    |5  |   | 8 |
    |49 | 5 |   |
    |   |  2|   |
    -------------".

Time Eval vm_compute in jos
"
    -------------
    |5  |   |   |
    | 4 |81 |   |
    | 93|   |  2|
    -------------
    |   |   |2 3|
    |9  |7  |   |
    |23 |  6| 7 |
    -------------
    |365|1  |   |
    |   | 5 |8  |
    |  1| 7 |6  |
    -------------".

Time Eval vm_compute in jos

"
    -------------
    |   |   | 6 |
    |43 | 5 |  2|
    |  7|832|4  |
    -------------
    |2  | 43|   |
    | 81|   |34 |
    |   |68 |  1|
    -------------
    |  3|719|6  |
    |7  | 6 | 14|
    | 6 |   |   |
    -------------".

(* L'escargot *)

Time Eval vm_compute in jos
"
    -------------
    |1  |  7| 9 |
    | 3 | 2 |  8|
    |  9|6  |5  |
    -------------
    |  5|3  |9  |
    | 1 | 8 |  2|
    |6  |  4|   |
    -------------
    |3  |   | 1 |
    | 4 |   |  7|
    |  7|   |3  |
    -------------".

(* Le Monde 4/3/07 *)

Time Eval vm_compute in jos

"
    -------------
    |2  | 68|   |
    | 69|   |   |
    |  7|1  |93 |
    -------------
    |   |   |8  |
    |9  |8  |5  |
    |35 |   | 4 |
    -------------
    | 12|7  |   |
    |   | 2 |6 5|
    |  5|   |4  |
    -------------".

(* Le monde 28/10/07 *)

Time Eval vm_compute in jos
"
    -------------
    |9  |  8|   |
    | 52|   |  1|
    |  4| 6 | 3 |
    -------------
    |   |   |   |
    |2  |1  |6  |
    |69 | 32| 1 |
    -------------
    |  7|5  |   |
    |   |   |8  |
    |  6| 93|5  |
    -------------".

(* Repubblica 6/05/2008 *)


Time Eval vm_compute in jos
"
    -------------
    |   |7  |5  |
    |   | 63|   |
    | 8 |  2|  1|
    -------------
    |  6|  4|2  |
    |24 |856| 79|
    |  3|2  |1  |
    -------------
    |7  |3  | 4 |
    |   |91 |   |
    |  2|  8|   |
    -------------".


(* TeleStar 12/05/2008 *)


Time Eval vm_compute in jos
"
    -------------
    |  2|  3| 9 |
    |9  |52 |   |
    |  3| 8 |4  |
    -------------
    |   |   |18 |
    |7  |   |  3|
    | 54|  6|   |
    -------------
    |  1| 6 |2 8|
    |   | 42| 1 |
    | 2 |3  | 7 |
    -------------".

(* Le monde 7/10/2008 *)


Time Eval vm_compute in jos
"
    -------------
    |5  | 37|1  |
    |   |   |   |
    | 16|2  |4 8|
    -------------
    |   |   |   |
    |   |5  |6  |
    |49 |  6| 35|
    -------------
    | 87|   |   |
    | 5 |38 |  6|
    |  3| 72|8  |
    -------------".



