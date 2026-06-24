# Regional Tool Scripts

Stata scripts and local ado dependencies for the Regional Tool workflow.

## Structure

- `00. master.do`: main entry point.
- `01. Pullglobals.do` through `10. Outputs - Tool.do`: workflow steps.
- `ado/`: local Stata ado programs used by the scripts.

## Notes

This repository intentionally tracks scripts and reusable ado files. Stata logs,
temporary files, and local package tracking files are ignored.
