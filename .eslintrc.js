module.exports = {
  extends: [],
  parserOptions: { ecmaVersion: 2018 },
  root: true,
  rules: {
    'prettier/prettier': ['error', { singleQuote: true }],
    'sort-imports': [
      'error',
      {
        ignoreCase: true,
        ignoreDeclarationSort: true,
        ignoreMemberSort: false,
      },
    ],
    'import/no-unresolved': 'off',
    'import/order': [
      'error',
      {
        groups: ['builtin', 'external', 'internal'],
        'newlines-between': 'always',
      },
    ],
    'no-plusplus': 'off',
    'no-undef': 'off',
    'func-names': 'off',
    'no-param-reassign': 'off',
    'no-console': 'off',
    'no-multi-str': 'off',
    'no-unused-expressions': 'off',
    'no-restricted-syntax': 'off',
  },
  overrides: [
    {
      files: ['test/**/*.spec.js'],
      env: {
        mocha: true,
      },
      globals: {
        artifacts: 'readonly',
        contract: 'readonly',
      },
      rules: {
        'no-await-in-loop': 'off',
      },
    },
  ],
};
