import '../../app/node';

import tests from '../runner';

tests.run()
.then(
  () => process.exit(0),
  () => process.exit(1)
)
