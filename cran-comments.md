## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

### Note on “possibly unsafe” calls (`unlockBinding`)

`R CMD check` reports:

```{r}
Found the following possibly unsafe calls:
File ‘caugi/R/caugi.R’:
  unlockBinding(nm, e)
File ‘caugi/R/verbs.R’:
  unlockBinding("built", s)
```

The package implements an immutable S7 object, `caugi`, whose internal state 
lives in a private environment created with `new.env(parent = emptyenv())`. 
At construction we lock all bindings and the environment to prevent accidental 
user mutation (`.freeze_state()`), then temporarily unlock only this private 
environment to perform internal updates and immediately re-lock 
(`.unfreeze_state()` and `.freeze_state()`). Verbs that change nodes/edges must 
mark the object as “not built” so the Rust view is rebuilt on demand. 
That requires flipping a single logical flag, hence `unlockBinding("built", s)` 
inside `.mark_not_built()` before re-locking.

Since S7 doesn't support private fields, we found that this was a solution to 
making the `caugi` graph objects only mutable through exported functions (and 
thus keeping it immutable through direct object manipulation). 

This is safe, since:

* Unlocking is restricted to the object’s own private environment. .
* The set of bindings unlocked is fixed by the package at object creation.
* All helpers that have this functionality are internal and unexported. 
* Every unlock is paired with a `lockBinding` and final `lockEnvironment`, 
  so there is no lingering writable state.

This pattern gives strong guarantees against accidental external mutation, 
while enabling controlled internal updates and deferred rebuilds of the 
Rust graph object. 
