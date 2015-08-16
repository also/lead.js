import Bacon from 'bacon.model';

export function componentList() {
  let components = [];
  let componentId = 1;
  const model = new Bacon.Model([]);

  return {
    model: model,

    addComponent(c) {
      components.push({
        component: c,
        key: componentId++
      });
      model.set(components.slice());
    },

    empty() {
      components = [];
      model.set([]);
    }
  };
}

export function addComponent(ctx, component) {
  return ctx.componentList.addComponent(component);
}

export function removeAllComponents(ctx) {
  return ctx.componentList.empty();
}
