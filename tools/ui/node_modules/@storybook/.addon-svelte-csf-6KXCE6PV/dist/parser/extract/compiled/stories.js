export async function extractStoriesNodesFromExportDefaultFn(params) {
    const { walk } = await import('zimmerframe');
    const { nodes } = params;
    const { storiesFunctionDeclaration, storyIdentifier } = nodes;
    const state = [];
    const visitors = {
        CallExpression(node, context) {
            const { state } = context;
            if (node.callee.type === 'Identifier' && node.callee.name === storyIdentifier.name) {
                state.push(node);
            }
            else {
                context.next();
            }
        },
    };
    walk(storiesFunctionDeclaration.body, state, visitors);
    return state;
}
