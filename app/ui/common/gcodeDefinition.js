const gcodeDefinition = {
  consts: [
    'true',
    'false',
    'iterations',
    'line',
    'null',
    'pi',
    'result',
    'input'
  ],
  functions: [
    'abs',
    'acos',
    'asin',
    'atan',
    'atan2',
    'cos',
    'degrees',
    'exists',
    'fileexists',
    'fileread',
    'floor',
    'isnan',
    'max',
    'min',
    'mod',
    'radians',
    'random',
    'sin',
    'sqrt',
    'tan',
    'vector'
  ],
  keywords: ['abort', 'echo', 'if', 'elif', 'while', 'set'],
  noArgKeywords: ['else', 'break', 'continue'],
  varKeywords: ['global', 'var'],
  symbols: /[=><!~?:&|+\-*#/^%]+/,
  operators: [
    '*',
    '/',
    '+',
    '-',
    '==',
    '!=',
    '=',
    '<=',
    '<',
    '>=',
    '>>>',
    '>>',
    '>',
    '!',
    '&&',
    '&',
    '||',
    '|',
    '^',
    '?',
    ':'
  ],
  includeLF: true,
  tokenizer: {
    root: [
      // keywords
      [
        /[a-z_$][\w$]*/,
        {
          cases: {
            '@keywords': { token: 'keyword', next: '@lineExpression' },
            '@noArgKeywords': { token: 'keyword' },
            '@varKeywords': { token: 'keyword', next: 'varName' }
          }
        }
      ],

      // G/M/T-codes
      [/G[01](?=\D)/, 'keyword', 'moveGcode'],
      [/(G|M)\d+(\.\d+)?/, 'keyword', 'normalGcode'],
      [/T[-]?\d+/, 'keyword', 'normalGcodeWithT'],

      // numbers
      [/\d*\.\d+([eE][-+]?\d+)?/, 'number.float'],
      [/0[xX][0-9a-fA-F]+/, 'number.hex'],
      [/\d+/, 'number'],

      // strings
      [/"(.|"")*?"/, 'string'],

      // comments
      [/;.*/, 'comment'],
      [/@.*/, 'comment']
    ],
    gcode: [
      // next G/M/T-code
      [/G[0123](?=\D)/, 'keyword', 'moveGcode'],
      [/(G|M)\d+(\.\d*)?/, 'keyword', 'normalGcode'],
      [/T/, 'keyword', 'normalGcodeWithT'],

      // parameter letters
      [/'?[A-Z]/, 'variable.name'],
      [/'[a-z]/, 'variable.name'],

      // expressions
      [/{/, 'operator', '@curlyBracket'],

      // enclosed comments
      [/\(.*\)/, 'comment'],

      // parameter expressions
      [/{/, 'expression', '@expression'],

      // include defaults
      { include: 'root' }
    ],
    moveGcode: [
      // G0/G1 does not support T parameters, starting a new T-code
      [/(?=T)/, 'keyword', '@popall'],

      // include normal gcode
      { include: 'gcode' }

      // no EOL to support Fanuc-style G-code
    ],
    normalGcode: [
      // include normal gcode
      { include: 'gcode' },

      // EOL
      [/\n/, '', '@popall']
    ],
    normalGcodeWithT: [
      // already had a T parameter, starting a new T-code
      [/(?=T)/, 'keyword', '@popall'],

      // include normal gcode
      { include: 'normalGcode' }
    ],
    expression: [
      // variables
      [/(global\.|param\.|var\.)[a-zA-Z]\w*/, 'variable.name'],

      // object model properties
      [/(\w+\.(\w+\.?)*|\.\w+(\.\w+)*)/, 'variable'],

      // consts and functions
      [
        /[a-z]\w*/,
        {
          cases: {
            '@consts': 'constant',
            '@functions': 'keyword'
          }
        }
      ],

      // nested expressions
      [/{/, 'operator', '@curlyBracket'],
      [/\[/, 'operator', '@squareBracket'],

      // numbers
      [/\d*\.\d+([eE][-+]?\d+)?/, 'number.float'],
      [/0[xX][0-9a-fA-F]+/, 'number.hex'],
      [/\d+/, 'number'],

      // strings and chars
      [/"(.|"")*?"/, 'string'],
      [/'.'/, 'string'],

      // operators
      [
        /@symbols/,
        {
          cases: {
            '@operators': 'operator',
            '@default': ''
          }
        }
      ],

      // comments
      [/;.*/, 'comment'],
      [/@.*/, 'comment'],

      // EOL
      [/\n/, '', '@popall']
    ],
    lineExpression: [
      // comments
      [/;.*/, 'comment'],
      [/@.*/, 'comment'],

      // line expressions are basically expressions
      { include: 'expression' }
    ],
    curlyBracket: [
      // curly brackets contain expressions
      { include: 'expression' },

      // terminate whern reaching a closing brackets
      [/}/, 'operator', '@pop']
    ],
    squareBracket: [
      // square brackets contain expressions
      { include: 'expression' },

      // terminate whern reaching a closing brackets
      [/\]/, 'operator', '@pop']
    ],
    varName: [
      // variable name
      [/[a-z_$][\w$]*/, 'variable.name', '@expression'],

      // EOL
      [/\n/, '', '@popall']
    ]
  }
}

export default gcodeDefinition
