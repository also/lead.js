import expect from 'expect.js';

import * as graphUtils from '../../app/graph/utils';

// the 3:4:5 triangle is nice for testing distances

describe('graph/utils', () => {
  describe('simplifyPoints', () => {
    it('collapses two identical points', () => {
      const original = [{x: 0, y: 0}, {x: 0, y: 0}];
      const simplified = graphUtils.simplifyPoints(10000, original);
      expect(simplified).to.eql([{x: 0, y: 0}]);
    });

    it('collapses nearby points', () => {
      const original = [{x: 0, y: 0}, {x: 3, y: 4}];
      const simplified = graphUtils.simplifyPoints(5, original);
      expect(simplified).to.eql([original[0]]);
    });

    it('keeps points that are > minDistance', () => {
      const original = [{x: 0, y: 0}, {x: 3, y: 5}];
      const simplified = graphUtils.simplifyPoints(5, original);
      expect(simplified).to.eql(original);
    });

    // it('discards initial null', () => {
    //   const original = [{x: 0, y: null}, {x: 0, y: 0}];
    //   const simplified = graphUtils.simplifyPoints(0, original);
    //   expect(simplified).to.eql([original[1]]);
    // });
  });
});
