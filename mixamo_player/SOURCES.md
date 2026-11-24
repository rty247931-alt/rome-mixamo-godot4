# Asset provenance

Model: **Y Bot**, Adobe Mixamo.

Downloaded directly through the user's signed-in Mixamo browser session on 2026-10-11:

| Bundled clip | Mixamo title | Download settings |
|---|---|---|
| Base model | Y Bot | FBX Binary, T-pose |
| Idle | Idle — Standing Idle | FBX Binary, Without Skin, 30 fps, no keyframe reduction |
| Walk | Walking — Walking With A Swagger | Same, In Place enabled |
| Run | Running — Running Forward Quickly | Same, In Place enabled |
| Jump | Jump — Jumping In Place | Same |
| Fall | Falling Idle — Mid-Air Falling Idle | Same |
| Land | Falling To Landing — Landing From Falling Idle | Same |

Source service: https://www.mixamo.com/
Adobe's Mixamo information: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html

Character and animation assets remain Adobe/Mixamo assets under their applicable terms; this file does not relicense them. The gameplay, camera, input, touch UI and demo scripts were written for this project.

Preparation: imported FBX using Godot 4.5.1's built-in ufbx importer; combined clips on the identical Y Bot skeleton; removed horizontal hip translation; normalized airborne hip height so CharacterBody3D owns the jump trajectory; trimmed the Jump takeoff and Land recovery; packed mesh, materials, skin and animation library into YBot.scn. Original FBX downloads are retained in the optional source archive.

No three.js reference model or third-party animation library is included in the delivered player.
