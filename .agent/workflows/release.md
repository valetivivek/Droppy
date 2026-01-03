---
description: Release a new version of Droppy
---

1. Ask the user for the **Version Number** (e.g., 2.0.3).
2. **Generate Release Notes**:
   - Run `git describe --tags --abbrev=0` to get the last tag.
   - Run `git log [LAST_TAG]..HEAD --pretty=format:"- %s"` to get the changes.
   - Summarize these changes into a user-friendly format (Features, Fixes, Improvements).
   - Write the summarized notes to `release_notes.txt`.
3. Run the release script with the auto-confirm flag:
   ```bash
   ./release_droppy.sh [VERSION] release_notes.txt -y
   ```
4. Verify the output confirms "DONE! Release is live."
5. Notify the user that the release is complete with the generated notes.
