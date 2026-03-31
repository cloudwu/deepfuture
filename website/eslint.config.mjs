import antfu from '@antfu/eslint-config'

export default antfu(
  {
    typescript: true,
    stylistic: {
      semi: false,
    },
  },
  {
    rules: {
      'style/semi': ['error', 'never'],
    },
  },
)
