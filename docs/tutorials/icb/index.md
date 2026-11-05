# Initial Fields (ICB)

ICB writes the state of every cell at the start of a run. Each tutorial uses the mesh and the phases of a test case
of `test/ICB/`.

| Tutorial | Case | You learn |
|----------|------|-----------|
| [A Uniform State, Block by Block](uniform.md) | `IG-2D` | `[ICB-Block*]` and `[ICB-BlockN]`, and the IC file |
| [Zones in a Block](zones.md) | `IG-multizone` | several states in one block |
| [Nozzle Flow](nozzle.md) | `IG-nozzle2D` | the isentropic flow of a De Laval nozzle |
| [Profiles From Tables](profiles.md) | `IG-species-profile-linear` | quantities that vary along the block |
| [Restart From Another Solution](restart.md) | `IG-interp-mindist` | a solution of another mesh as the start |
| [A Gas With Particles](particles.md) | `IG+DP` | a gas and its dispersed phase |
