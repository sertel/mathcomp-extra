From mathcomp Require Import all_ssreflect.

From mathcomp Require Import all_algebra.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Definition digitn b n m := (n %/ b ^ m) %% b.

Lemma digit0n b m : digitn b 0 m = 0.
Proof. by rewrite /digitn div0n mod0n. Qed.

Lemma digitn0 b n : digitn b n 0 = n %% b.
Proof. by rewrite /digitn divn1. Qed.

Lemma digitnS b n m : digitn b n m.+1 = digitn b (n %/ b) m.
Proof. by rewrite /digitn -divnMA expnS. Qed.

Lemma ltn_pdigit b n m : 0 < b -> digitn b n m < b.
Proof. by apply: ltn_pmod. Qed.

Lemma digitnE b n m : n < b ^ m -> n = \sum_(i < m) digitn b n i * b ^ i.
Proof.
elim: m n => [[]//=|m IH n nLb]; first by rewrite big_ord0.
rewrite {1}(divn_eq n b) [n %/ b]IH; last first.
  rewrite (divn_eq n b) in nLb.
  have := leq_ltn_trans (leq_addr _ _) nLb.
  by rewrite expnS mulnC ltn_mul2l => /andP[].
rewrite big_ord_recl addnC digitn0 muln1; congr (_ + _).
rewrite (big_morph _ (fun x y => mulnDl x y b) (mul0n b)).
apply: eq_bigr => /= i _.
by rewrite digitnS expnS mulnAC mulnA.
Qed.

Lemma digitn_uniq b n k (f : {ffun 'I_k -> 'I_b}) i :
  n < b ^ k -> n = (\sum_(i < k) f i * b ^ i)%N -> 
  f i = digitn b n i :> nat.
Proof.
elim: k n f i => [[|] f [] //|k IH n f i nLb].
have b_pos : 0 < b by case: (b) nLb => //; rewrite exp0n.
rewrite big_ord_recl /= muln1 => nE.
have f0E : f ord0 = n %% b :> nat.
  rewrite nE -modnDm -modn_summ big1 => [| j _].
    by rewrite mod0n addn0 modn_mod modn_small.
  by rewrite /bump add1n expnS mulnCA modnMr.
have /IH H : n %/ b = \sum_(i < k) [ffun i => f (lift ord0 i)] i * b ^ i.
  move/eqP: nE.
  rewrite f0E {1}(divn_eq n b) addnC eqn_add2l.
  under eq_bigr do rewrite /bump add1n expnS mulnCA.
  rewrite -big_distrr /= mulnC eqn_mul2l.
  rewrite eqn_leq leqNgt b_pos /= => /eqP->.
  by apply: eq_bigr => j _; rewrite !ffunE.
case i => [] [Hi|j Hj] /=.
  by rewrite digitn0 -f0E; congr (f _); apply/val_eqP.
rewrite digitnS.
have <- := H (Ordinal (Hj : j < k)).
  by rewrite ffunE /=; congr (f _); apply/val_eqP.
by rewrite ltn_divLR // mulnC -expnS.
Qed.

Import GRing.Theory.
Local Open Scope ring_scope.

Section ExtraLemma.

Variable R : ringType.

Lemma expr_sum (I : Type) (s : seq I) (P : pred I) (F : I -> nat) x : 
  x ^+ (\sum_(i <- s | P i) F i) = 
  \prod_(i <- s | P i) x ^+ F i :> R.
Proof. by apply: (big_morph _ (exprD _)). Qed.

Lemma prodMrn  (I : Type) (s : seq I) (P : pred I) 
               (f : I -> R) (g : I -> nat) : 
  \prod_(i <- s | P i) (f i *+ g i) = 
  \prod_(i <- s | P i) (f i) *+ \prod_(i <- s | P i) g i.
Proof.
elim/big_rec3: _ => // i y1 y2 y3 _ ->.
by rewrite !(mulrnAl, mulrnAr, mulrnA) -mulrnA mulnC mulrnA.
Qed.

Lemma mulrn_prod n (I : finType) (A : pred I) (F : I -> R) :
  \prod_(i in A) (F i *+ n) = \prod_(i in A) F i *+ n ^ #|A|.
Proof. by rewrite prodMrn // prod_nat_const. Qed.

Variable p : nat.
Hypothesis Pp : prime p.

Lemma Fp_exprnD (p1 p2 : {poly 'F_p}) : (p1 + p2) ^+ p = p1 ^+ p + p2 ^+ p.
Proof.
rewrite -[X in _ ^+ X](prednK (prime_gt0 Pp)).
rewrite exprDn big_ord_recl /= subn0 mulr1 bin0 mulr1n.
rewrite big_ord_recr /bump add1n //= !prednK ?prime_gt0 //; congr (_ + _).
rewrite subnn binn mul1r mulr1n big1 ?add0r // => i _.
have /dvdnP[k ->] : (p %| 'C(p, (0 <= i) + i))%N.
   apply: prime_dvd_bin Pp _ => //.
   by rewrite add1n andTb -[X in (_ < X)%N](prednK (prime_gt0 Pp)) ltnS.
by rewrite mulrnA -mulr_natr -polyC1 -polyC_muln char_Fp_0 // polyC0 !mulr0.
Qed.

Lemma Fp_exprnDn n (p1 p2 : {poly 'F_p}) :
  (p1 + p2) ^+ (p ^ n) = p1 ^+ (p ^ n) + p2 ^+ (p ^ n).
Proof. by elim: n => // n IH; rewrite expnS mulnC !exprM IH Fp_exprnD. Qed.

End ExtraLemma.

Section Lucas.

Variable R : ringType.
Variable p : nat.
Hypothesis Pp : prime p.

Lemma bin_lucas m n k : 
  (m < p ^ k -> n < p ^ k -> 
 'C(m, n) = \prod_(i < k) 'C(digitn p m i, digitn p n i) %[mod p])%N.
Proof.
move=> mLp nLp.
have [nLm | mLn] := leqP n m; last first.
  suff [i Hi] : exists i : 'I_k, (digitn p m i < digitn p n i)%N.
    by rewrite (bigD1 i) //= !bin_small.
  apply/existsP; apply: contraTT mLn.
  rewrite negb_exists -leqNgt => /forallP dmLdn.
  rewrite (digitnE nLp) (digitnE mLp) leq_sum // => i _.
  by rewrite leq_mul2r leqNgt dmLdn orbT.
have -> : ('C(m, n) %% p)%N = ((1 + 'X) ^+ m : {poly 'F_p})`_n.
  have nLm1 : (n < m.+1)%N by apply: leq_trans nLm.
  rewrite exprDn coef_sum.
  under eq_bigr do rewrite expr1n mul1r coefMn coefXn.
  rewrite (bigD1 (Ordinal nLm1)) //= eqxx mulr1n big1 => [|i /eqP/val_eqP/=].
    by rewrite [X in (_ = _ %% X)%N]Fp_cast // addn0 val_Fp_nat // modn_mod.
  by rewrite eq_sym => /negPf->; rewrite mulr0n // mul0rn.
rewrite {1}(digitnE mLp) expr_sum.
under eq_bigr do rewrite mulnC exprM Fp_exprnDn // expr1n exprDn.
have H i : 
  \sum_(j < (digitn p m i).+1)
    1 ^+ (digitn p m i - j) * 'X^(p ^ i) ^+ j *+ 'C(digitn p m i, j) =
  \sum_(j < p) 'X^(p ^ i) ^+ j *+ 'C(digitn p m i, j).
  under eq_bigr do rewrite expr1n mul1r.
  rewrite -!(big_mkord xpredT (fun j => 'X^(p ^ i) ^+ j *+ 'C(digitn p m i, j))).
  rewrite (big_cat_nat _ _ _  _ (ltn_pdigit m i (prime_gt0 Pp))) //=.
  rewrite [X in _ = _ + X]big_nat_cond [X in _ = _ + X]big1 ?addr0 // => j.
  by case/andP=> /andP[/bin_small->]; rewrite mulr0n.
under eq_bigr do rewrite {}H.
rewrite bigA_distr_bigA /= coef_sum.
under eq_bigr do under eq_bigr do rewrite -exprM mulnC.
under eq_bigr do rewrite prodMrn -expr_sum coefMn coefXn.
pose f := [ffun i : 'I_k =>  Ordinal (ltn_pdigit n i (prime_gt0 Pp))].
rewrite (bigD1 f) //= [X in (_ %% X)%N]Fp_cast //= .
rewrite [in X in ((_ + X) = _ %[mod _])%N]big1 ?addn0 => [| i iDf].
  rewrite (_ : _ == _) ?mulr1n.
    under eq_bigr do rewrite ffunE /=.
    by rewrite val_Fp_nat // modn_mod.
  apply/eqP; rewrite {1}[n](digitnE nLp); apply: eq_bigr => /= i _.
  by rewrite ffunE.
case: (n =P _) => nEs //; last by rewrite mul0rn.
case/eqP: iDf; apply/ffunP => j; apply/val_eqP =>/=.
by rewrite (digitn_uniq _ _ nEs) // ffunE.
Qed.

End Lucas.

