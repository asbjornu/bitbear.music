const path = require('path');

// Jekyll SCSS files may start with a YAML front matter block, which isn't
// valid SCSS. `scripts/stylelint-jekyll-scss.cjs` blanks it (preserving
// line/column positions) before parsing. The absolute path is resolved here
// so the config works regardless of the working directory.
//
// The core `indentation` rule was removed in Stylelint 16; `@stylistic/stylelint-plugin`
// provides the maintained `@stylistic/indentation` so the rule survives major upgrades.
module.exports = {
  customSyntax: path.join(__dirname, 'scripts', 'stylelint-jekyll-scss.cjs'),
  plugins: ['@stylistic/stylelint-plugin'],
  rules: {
    '@stylistic/indentation': 4,
  },
};
