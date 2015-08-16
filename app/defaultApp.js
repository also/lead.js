export const modules = {
  http: require('./http'),
  dsl: require('./dsl'),
  compat: require('./compat'),
  graphing: require('./graphing'),
  input: require('./input'),
  settings: require('./settings'),
  context: require('./context'),
  builtins: require('./builtins'),
  notebook: require('./notebook'),
  server: require('./server'),
  github: require('./settings')
};

export const imports = [
  'builtins.*',
  'server.*',
  'github.*',
  'graphing.*',
  'compat.*'
];
