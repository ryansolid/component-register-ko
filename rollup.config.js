import coffee2 from 'rollup-plugin-coffee2';
import nodeResolve from '@rollup/plugin-node-resolve';

const plugins = [
  coffee2(),
  nodeResolve({ extensions: ['.js', '.coffee'] })
]

export default [{
  input: 'src/index.coffee',
  output: [{
    file: 'lib/component-register-ko.js',
    format: 'cjs',
    exports: 'named'
  }, {
    file: 'dist/component-register-ko.js',
    format: 'es'
  }],
  external: ['knockout', 'component-register', 'component-register-extensions'],
  plugins
}, {
  input: 'src/preprocessor.coffee',
  output: {
    file: 'lib/preprocessor.js',
    format: 'cjs',
  },
  external: ['html-parse-string'],
  plugins
}]