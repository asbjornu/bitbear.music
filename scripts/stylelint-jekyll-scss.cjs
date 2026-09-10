const scss = require('postcss-scss');

// Jekyll SCSS files may begin with a YAML front matter block delimited by
// `---`. That block isn't valid SCSS, so blank its characters (preserving
// newlines) before parsing — this keeps stylelint's reported line/column
// numbers accurate without dropping the front matter from the source file.
// Stylelint's `customSyntax` expects a syntax object with `parse`/`stringify`,
// so forward to `postcss-scss` after preprocessing the source.
module.exports = {
  parse: (css, opts) =>
    scss.parse(
      css.replace(/^---\n[\s\S]*?\n---/, (match) => match.replace(/[^\n]/g, ' ')),
      opts
    ),
  stringify: scss.stringify,
};
