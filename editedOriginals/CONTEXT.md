# editedOriginals — Context

This folder contains corrected versions of scripts from the DNA + MUA + ion pipeline.

These scripts preserve the original workflow but fix bugs that affected parsing and lifetime calculations.

## Errors fixed

- Wrap-around issue with `index[0]`  
  Fixed incorrect boundary handling that caused missed or duplicated binding events.

- Header discard redesign  
  Improved handling of `.xvg` headers (`#`, `@`) to ensure only valid data is parsed.

## Note

The original, unmodified scripts are stored in the `archive/` folder.