import '../../app/node';

import {run} from './runner';

run()
.then(
  () => process.exit(0),
  () => process.exit(1)
)
