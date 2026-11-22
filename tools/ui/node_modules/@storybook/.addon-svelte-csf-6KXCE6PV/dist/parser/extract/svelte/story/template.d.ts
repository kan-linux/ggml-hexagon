import type { SvelteAST } from '../../../ast.js';
type Result = SvelteAST.SnippetBlock | undefined;
/**
 * Extract the {@link SnippetBlock}  of the individual `<Story />` if exists.
 *
 * This AST node will help us in the further transformation of the `parameters.docs.source.code` on the compiled code,
 * and at runtime.
 */
export declare function extractStoryTemplateSnippetBlock(component: SvelteAST.Component): Result;
export {};
