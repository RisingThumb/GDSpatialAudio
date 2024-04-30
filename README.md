# gd_spatial_audio

## Motive

Godot currently doesn't have any good acoustic options. This exists to fix that.

## How to use

- Make a new ExpandedPhysicsMaterial with the data you want
- Add it to any StaticBody3D.
- You can then from raycasts get the material.
- You add and play SpatialAudioPlayer3D nodes where you want them
- They have 4 additional properties
- - max_raycast_distance for the max distance you can hear this node/do raycast checks for it
- - update_frequency_seconds, for how often it should be sampling the environment. This defaults to using some randomness, so it doesn't check every frame
- - max_rever_wetness, so your sounds have a maximum to how distorted they are. Some sounds are high-importance design-wise so shouldn't be distorted much acoustically
- - wall_lowpass_cutoff_amount, frequency to cut off sounds when blocked by a wall. This combines with an expandedPhysicsMaterial's sound coefficients

## Notes

The initial implementation is based partly on blekoh's [implementation](https://www.youtube.com/watch?v=mHokBQyB_08).
The expandedPhysicsMaterial is used to get around Godot's inability to tell what texture you collide with. This gets around it. The mapper exists as a resource for mapping texture suffixes to an expandedPhysicsMaterial. It's up to you if you want to use that.
Additional notes can be found here on my [site](https://risingthumb.xyz/Tech/Game_Dev/Audio_Acoustics)
