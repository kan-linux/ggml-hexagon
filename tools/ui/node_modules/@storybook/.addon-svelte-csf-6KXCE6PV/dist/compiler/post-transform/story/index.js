import { print } from 'esrap';
import { insertStoryHTMLCommentAsDescription } from './insert-description.js';
import { insertSvelteCSFToStoryParameters } from './insert-svelte-csf.js';
/**
 * Transform compiled `<Story />` component when necessary,
 * and print updated AST node of compiled version to original raw source code {@link MagicString}.
 */
export function transformStory(params) {
    const { code, nodes, filename, originalCode } = params;
    const { component } = nodes;
    insertStoryHTMLCommentAsDescription({
        nodes: component,
        filename,
    });
    insertSvelteCSFToStoryParameters({
        nodes,
        filename,
        originalCode,
    });
    const { compiled } = component;
    const { start, end } = compiled;
    code.update(start, end, print(compiled).code);
}
