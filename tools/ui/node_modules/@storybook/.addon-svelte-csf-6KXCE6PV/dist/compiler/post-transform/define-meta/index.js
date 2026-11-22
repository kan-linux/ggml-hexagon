import { print } from 'esrap';
import { replaceDefineMetaArgument } from './replace-argument.js';
import { insertDefineMetaParameters } from './insert-parameters.js';
import { STORYBOOK_META_IDENTIFIER } from '../../../constants.js';
import { createASTIdentifier } from '../../../parser/ast.js';
/**
 * Attempt to transform compiled `defineMeta()` when necessary.
 * And in the end, update the compiled code using {@link MagicString}.
 */
export function transformDefineMeta(params) {
    const { code, nodes, filename } = params;
    insertDefineMetaParameters({ nodes, filename });
    const metaObjectExpression = replaceDefineMetaArgument({ nodes, filename });
    const metaVariableDeclaration = createMetaVariableDeclaration({ init: metaObjectExpression });
    const { compiled } = nodes;
    const { defineMetaVariableDeclaration } = compiled;
    const { start, end } = defineMetaVariableDeclaration;
    code.update(start, end, print(defineMetaVariableDeclaration).code);
    code.appendLeft(start, print(metaVariableDeclaration).code + '\n');
}
export function createMetaVariableDeclaration({ init, }) {
    return {
        type: 'VariableDeclaration',
        kind: 'const',
        declarations: [
            {
                type: 'VariableDeclarator',
                id: createASTIdentifier(STORYBOOK_META_IDENTIFIER),
                init,
            },
        ],
    };
}
