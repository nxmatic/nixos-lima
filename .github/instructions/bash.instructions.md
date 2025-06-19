applyTo:
  contextContains: bash
Coding standards, domain knowledge, and preferences that AI should follow.

# File Generation Standard
When generating files in bash, always prefer using a here document (heredoc) piped to `cut` to manage indentation, and then piped to `tee` to write the output file. This ensures readable, indented output and visible file creation in the logs.  The indent level of the heredoc should match the indentation of the surrounding code block, ensuring that the heredoc content is correctly indented when written to the file. Example:

```bash
  cat <<EoF | cut -c 3- | tee /path/to/file
  ...indented content...
EoF

# Comments
Instead of using `#` for comments, use `:`. This is useful for debugging and understanding the flow of the script. Example:

```bash
: This is a comment that will be visible in trace mode
```
