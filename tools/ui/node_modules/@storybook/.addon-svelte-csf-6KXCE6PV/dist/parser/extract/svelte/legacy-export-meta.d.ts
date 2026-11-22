import type { ObjectExpression, Property } from 'estree';
import type { SvelteASTNodes } from './nodes.js';
import type { CompiledASTNodes } from '../compiled/nodes.js';
import type { Cmp, ComponentAnnotations } from '../../../types.js';
interface Options<Properties extends Array<keyof ComponentAnnotations<Cmp>>> {
    nodes: SvelteASTNodes | CompiledASTNodes;
    properties: Properties;
    filename?: string;
}
type Result<Properties extends Array<keyof ComponentAnnotations<Cmp>>> = Partial<{
    [Key in Properties[number]]: Property;
}>;
/**
 * Extract selected properties from `defineMeta` as AST node {@link Property}.
 * It works for original svelte code as well as compiled code,
 * because in both cases, the AST structure is the same _(or should be!)_.
 */
export declare function extractLegacyExportMetaPropertiesNodes<const Properties extends Array<keyof ComponentAnnotations<Cmp>>>(options: Options<Properties>): Result<Properties>;
/**
 * `defineMeta` accepts only one argument - an {@link ObjectExpression},
 * which should satisfy `@storybook/svelte`'s interface {@link Meta}.
 */
export declare function getLegacyExportMetaObjectExpression(options: Pick<Options<Array<keyof ComponentAnnotations<Cmp>>>, 'filename' | 'nodes'>): ObjectExpression;
export {};
