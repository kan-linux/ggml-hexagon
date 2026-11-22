/**
 * Extract Svelte AST nodes via `svelte.compile`,
 * and from the fragment aka HTML code.
 * They are needed for further code analysis/transformation.
 */
export async function extractFragmentNodes(params) {
    const { walk } = await import('zimmerframe');
    const { fragment, moduleNodes } = params;
    const { storyIdentifier } = moduleNodes;
    let latestComment;
    const state = {
        storyComponents: [],
        snippetBlocks: [],
    };
    const visitors = {
        Comment(node, { next }) {
            latestComment = node;
            next();
        },
        Component(node, { state }) {
            if (node.name === storyIdentifier.name) {
                state.storyComponents.push({
                    comment: latestComment,
                    component: node,
                });
                latestComment = undefined;
            }
        },
        SnippetBlock(node, { state }) {
            state.snippetBlocks.push(node);
        },
    };
    walk(fragment, state, visitors);
    return state;
}
