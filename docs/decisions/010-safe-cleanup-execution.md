# ADR 010: Safe Cleanup Execution

## Status

Accepted

## Decision

- Cleanup scanning is read-only and limited to explicit user-library roots.
- Candidates are classified as `safe` or `review` with a plain-language reason.
- Quick Clean executes only `safe` candidates after the user presses its dedicated control.
- Review candidates require explicit selection and confirmation.
- Approved files move to Trash through a thin `FileTrashMoving` boundary.
- JoeyPet never empties Trash and requires neither sudo nor Full Disk Access.
- The app target is not App Sandbox-enabled so the allowlisted user-library roots are visible under normal user permissions; no broader roots are granted by the product.

## Consequences

Discovery and execution remain separate, tests can use a fake mover, and
partial failures can be reported without risking a broad rollback or silent
deletion.
