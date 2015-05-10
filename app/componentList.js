import Bacon from 'bacon.model';

export const componentList = function() {
  let components = [];
  let componentId = 1;
  const model = new Bacon.Model([]);
  return {
    model: model,
    addComponent: function(c) {
      components.push({
        component: c,
        key: componentId++
      });
      return model.set(components.slice());
    },
    empty: function() {
      components = [];
      return model.set([]);
    }
  };
};

export const addComponent = function(ctx, component) {
  return ctx.componentList.addComponent(component);
};

export const removeAllComponents = function(ctx) {
  return ctx.componentList.empty();
};
