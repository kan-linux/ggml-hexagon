import { StorybookSvelteCSFError } from '../../../error.js';
import type * as ESTreeAST from 'estree';
export declare class InvalidComponentValueError extends StorybookSvelteCSFError {
    readonly category: "PARSER_ANALYSE_DEFINE_META";
    readonly code = 1;
    documentation: boolean;
    componentProperty: ESTreeAST.Property;
    constructor({ filename, componentProperty, }: {
        filename: StorybookSvelteCSFError['filename'];
        componentProperty: InvalidComponentValueError['componentProperty'];
    });
    template(): string;
}
export declare class NoDestructuredDefineMetaCallError extends StorybookSvelteCSFError {
    readonly category: "PARSER_ANALYSE_DEFINE_META";
    readonly code = 2;
    documentation: boolean;
    node: ESTreeAST.VariableDeclarator;
    constructor({ filename, defineMetaVariableDeclarator, }: {
        filename: StorybookSvelteCSFError['filename'];
        defineMetaVariableDeclarator: NoDestructuredDefineMetaCallError['node'];
    });
    template(): string;
}
export declare class NoStringLiteralError extends StorybookSvelteCSFError {
    readonly category: "PARSER_ANALYSE_DEFINE_META";
    readonly code = 3;
    documentation: boolean;
    readonly property: ESTreeAST.Property;
    constructor({ filename, property, }: {
        filename: StorybookSvelteCSFError['filename'];
        property: NoStringLiteralError['property'];
    });
    template(): string;
}
export declare class NoArrayExpressionError extends StorybookSvelteCSFError {
    readonly category: "PARSER_ANALYSE_DEFINE_META";
    readonly code = 4;
    documentation: boolean;
    readonly property: ESTreeAST.Property;
    constructor({ filename, property, }: {
        filename: StorybookSvelteCSFError['filename'];
        property: NoArrayExpressionError['property'];
    });
    template(): string;
}
export declare class ArrayElementNotStringError extends StorybookSvelteCSFError {
    readonly category: "PARSER_ANALYSE_DEFINE_META";
    readonly code = 5;
    documentation: boolean;
    readonly property: ESTreeAST.Property;
    readonly element: ESTreeAST.ArrayExpression['elements'][number];
    constructor({ filename, property, element, }: {
        filename: StorybookSvelteCSFError['filename'];
        property: ArrayElementNotStringError['property'];
        element: ArrayElementNotStringError['element'];
    });
    template(): string;
}
export declare class InvalidRenderValueError extends StorybookSvelteCSFError {
    readonly category: "PARSER_ANALYSE_DEFINE_META";
    readonly code = 6;
    documentation: boolean;
    renderProperty: ESTreeAST.Property;
    constructor({ filename, renderProperty, }: {
        filename: StorybookSvelteCSFError['filename'];
        renderProperty: InvalidRenderValueError['renderProperty'];
    });
    template(): string;
}
