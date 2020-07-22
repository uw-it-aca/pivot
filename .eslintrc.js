module.exports = {
    'env': {
      'browser': true,
      'commonjs': true,
      'es6': true,
      "jquery": true
    },
    "plugins": [
        "jquery"
    ],
    'extends': [
      'google',
      'stylelint',
      'plugin:node/recommended',
      "plugin:jquery/slim"
    ],
    'globals': {
      'Atomics': 'readonly',
      'SharedArrayBuffer': 'readonly',
    },
    'parserOptions': {
      'ecmaVersion': 2019,
      'sourceType': 'module',
    },
    'rules': {
      'node/no-unsupported-features/es-syntax': 'off',
      'no-unused-vars': 'off',
      'require-jsdoc': 'off',
      'no-undef': 'off',
    },
  };
  