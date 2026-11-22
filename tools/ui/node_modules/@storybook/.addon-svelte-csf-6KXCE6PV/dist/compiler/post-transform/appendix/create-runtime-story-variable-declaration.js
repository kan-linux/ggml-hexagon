import { STORYBOOK_INTERNAL_PREFIX, SVELTE_CSF_TAG_PREFIX, SVELTE_CSF_V5_TAG, } from '../../../constants.js';
import { createASTArrayExpression, createASTIdentifier, createASTObjectExpression, createASTProperty, } from '../../../parser/ast.js';
export function createRuntimeStoryVariableDeclaration(params) {
    const tags = createASTArrayExpression(params.nodes.tags?.elements);
    // In legacy stories, the pre-transform will add a SVELTE_CSF_V4_TAG tag.
    // if it is not present, we add the SVELTE_CSF_V5_TAG tag.
    const hasSvelteCsfTag = tags.elements.some((element) => element?.type === 'Literal' && element.value?.toString().startsWith(SVELTE_CSF_TAG_PREFIX));
    if (!hasSvelteCsfTag) {
        tags.elements.push({
            type: 'Literal',
            value: SVELTE_CSF_V5_TAG,
        });
    }
    return {
        type: 'VariableDeclaration',
        kind: 'const',
        declarations: [
            {
                type: 'VariableDeclarator',
                id: createASTIdentifier(`${STORYBOOK_INTERNAL_PREFIX}${params.exportName}`),
                init: createASTObjectExpression([
                    {
                        type: 'SpreadElement',
                        argument: {
                            type: 'MemberExpression',
                            computed: true,
                            optional: false,
                            object: params.nodes.variable.declarations[0].id,
                            property: { type: 'Literal', value: params.exportName },
                        },
                    },
                    createASTProperty('tags', tags),
                ]),
            },
        ],
    };
}
