## Mars horizon mini-game solver ##

Gives guidance during mars solver mini-games.

Features:
* optimizes number of actions to let user account for incidents requiring extra-⚡
* help with 🔥, 🚀, crew management
* suggest to let ⚡ recharge when necessary

Downsides:
* does not predict incidents
* when 🔥 gain is random, solver accounts for the worst case. This is a downside since many interesting reactions requires heat. User need to delay those reactions until enough heat

### How to use ###

Enter parameters in solve, then run ./solve

= How to improve =

Simply edit solver.rb. Please consider add a test for new features / bugfix.
