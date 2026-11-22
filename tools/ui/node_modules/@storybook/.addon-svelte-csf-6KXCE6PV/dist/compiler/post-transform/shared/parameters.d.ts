import { type ESTreeAST, type SvelteAST } from '../../../parser/ast.js';
interface FindPropertyOptions {
    name: string;
    node: ESTreeAST.ObjectExpression;
    filename?: string;
    component?: SvelteAST.Component;
}
/**
 * In order to be able to access AST node - {@link Property} - from the {@link ObjectExpression},
 * we need to have its index based on the property name, so the key must be an identifier.
 * NOTE: Reminder, it always returns a number and `-1` means not found.
 */
export declare function findASTPropertyIndex(options: FindPropertyOptions): number;
export declare const findPropertyParametersIndex: (options: Omit<FindPropertyOptions, "name">) => number;
export declare const getParametersProperty: (options: Omit<FindPropertyOptions, "name">) => ESTreeAST.Property;
export declare const getParametersPropertyValue: (options: Omit<FindPropertyOptions, "name">) => ESTreeAST.ObjectExpression;
export declare const findPropertyDocsIndex: (options: Omit<FindPropertyOptions, "name">) => number;
export declare const getDocsProperty: (options: Omit<FindPropertyOptions, "name">) => ESTreeAST.Property;
export declare const getDocsPropertyValue: (options: Omit<FindPropertyOptions, "name">) => ESTreeAST.ObjectExpression;
export declare const findPropertyDescriptionIndex: (options: Omit<FindPropertyOptions, "name">) => number;
export declare const getDescriptionProperty: (options: Omit<FindPropertyOptions, "name">) => ESTreeAST.Property;
export declare const getDescriptionPropertyValue: (options: Omit<FindPropertyOptions, "name">) => ESTreeAST.ObjectExpression;
export {};
