= Introduction
<introduction>
+ model provides a missing link between debates on financialization ond
  PK models that are mostly focused on the real economy.

+ the notion of specullation and liquidty preference has always been
  there, but whether and to what extent it has an impact is debate.
  while for mainstreamers money as a whole is only a vial, Keynes
  emphaizses that the demand for money -- e.g. in the form of hoarded
  savings -- can have real impacts. however, in treatise of money he
  denies that the supply of money for speculative purposes has such
  impact. our approach shows what happens if there is such a link and
  clarifies the most obvious assumptions that come with imposing one in
  a general framework of endogenous money.

+ our argument on turnover implicitly creates a multiplier that governs
  the mismatch in scale between speculative transactions and GDP (also
  already discussed in the Treatise!)

= A simple static model
<a-simple-static-model>
== The core model
<the-core-model>
Three versions:

+ In the first one just speculation is added and it is shown how this
  inflates balance sheets.

+ In the second one we impoase the link via c to show this has real
  impact. we could compare this with a scenario of rising inequality.

+ we do the same as in c with a different notion of causality, where
  increasing totals bank balance sheets constrain lending to that the
  reaction of the banking sector is modeled in greater detaill. should
  give a result similar to (b) that is better explained.

== Endogenizing $alpha$ - towards an endogenous asset turnover rate
<endogenizing-alpha---towards-an-endogenous-asset-turnover-rate>
== Endogenizing $c$ - credit constrains through speculation
<endogenizing-c---credit-constrains-through-speculation>
=== Dual interest rate policies
<dual-interest-rate-policies>
== Policies
<policies>
→ for this we need some 2/4 standard panel to Xplain results.

= Steps towards a dynamic model
<steps-towards-a-dynamic-model>

The goal is to establish a dynamic model, that can capture hysteresis effects aswell as the nonlinear dynamics of the static versions

The core model without the assset market stays unchanged

$
&Y_t = "ND"_t + c  D_t \
&"ND"_t = b  Y_t \
&D_t = d_0 - d_1  r_t \
&i_t = i_0 + i_1  P_t \
&r_t = (1 + m)  i_t \
&"dL"_t = c  D_t + "SD"_t \
&"dM"_t = "dL"_t \
&"dR"_t = k "dM"_t \
&P_t = (1 + n)  a  W_t \
&W_t = W_0 - h  U_t \
&N_t = a  Y_t \
&U_t = 1 - N_t / N^f \
$

In the asset market the asset supply changees from the static model in that we partially endogenize $"AQ"$ by assuming that $"AQ"$ grows by the factor $g_alpha$ through new assets being created.
Of these new assets $beta$ are sold to inverstors, while $(1 - beta)$ are held back in reserves 



$
&"SD"_t = s_0 - s_1 r    \
&"AD"_t = gamma_0 + (1 / (1 - gamma)) "SD"_t / "AP"_t \
&"AQ"_t = (1+ g_alpha) "AQ"_(t-1) \
&"AS"_t = alpha "AQ"_(t) \
&"AP"_t = p_1 "AD"_t/"AS"_t \
$

or alternatively if we allow firms to keep back assets at a factor $1- beta$ we could adjust this to
$
&"SD"_t = s_0 - s_1 r    \
&"AD"_t = gamma_0 + (1 / (1 - gamma)) "SD"_t / "AP"_t \
&"AQ"_t = (1+ g_alpha) "AQ"_(t-1) \
&"AC"_t = "AC"_(t-1) + beta ("AQ"_(t) - "AQ"_(t-1)) - alpha_0 "AC"_t\
&"AF"_t = "AF"_(t-1) + (1 - beta) ("AQ"_(t) - "AQ"_(t-1)) - alpha_1 "AF"_(t-1)\
&"AS"_t = alpha_0 "Ac"_(t) + alpha_1 "AF"_(t-1) + beta ( "AQ"_(t) - "AQ"_(t-1))   \
&"AP"_t = p_1 "AD"_t/"AS"_t \
$


Following the same procedure as the static model we now try to endogenize $alpha$ 
We assume that the decision in which quantity to sell assets is taken on previous period prices
So the equations for $alpha$ is given as

$
alpha = s("AP"_(t-1))
$


where $s$ could be either linear, or a more complex function that incorporates panic selling 
(e.g $\s("AP") = omega_p / (1 + e^(k_p ("AP" - P_p))) + omega_h / (1 + e^(-k_h ("AP" - P_h)))$



