import type { SvelteAST } from '../../../../parser/ast.js';
import type { SvelteASTNodes } from '../../../../parser/extract/svelte/nodes.js';
import { StorybookSvelteCSFError } from '../../../error.js';
export declare class MissingModuleTagError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 1;
    documentation: boolean;
    constructor(filename?: string);
    template(): string;
}
export declare class DefaultOrNamespaceImportUsedError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 2;
    documentation: boolean;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class MissingDefineMetaImportError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 3;
    documentation: boolean;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class MissingDefineMetaVariableDeclarationError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 4;
    documentation: boolean;
    constructor(filename?: StorybookSvelteCSFError['filename']);
    template(): string;
}
export declare class NoStoryComponentDestructuredError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 5;
    documentation: boolean;
    defineMetaImport: SvelteASTNodes['defineMetaImport'];
    constructor({ filename, defineMetaImport, }: {
        filename?: StorybookSvelteCSFError['filename'];
        defineMetaImport: NoStoryComponentDestructuredError['defineMetaImport'];
    });
    template(): string;
}
export declare class GetDefineMetaFirstArgumentError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 6;
    documentation: boolean;
    defineMetaVariableDeclaration: SvelteASTNodes['defineMetaVariableDeclaration'];
    constructor({ filename, defineMetaVariableDeclaration, }: {
        filename?: StorybookSvelteCSFError['filename'];
        defineMetaVariableDeclaration: SvelteASTNodes['defineMetaVariableDeclaration'];
    });
    template(): string;
}
export declare class InvalidStoryTemplateAttributeError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 7;
    documentation: boolean;
    templateAttribute: SvelteAST.Attribute;
    constructor({ filename, component, templateAttribute, }: {
        filename?: StorybookSvelteCSFError['filename'];
        component: NonNullable<StorybookSvelteCSFError['component']>;
        templateAttribute: InvalidStoryTemplateAttributeError['templateAttribute'];
    });
    template(): string;
}
export declare class IndexerParseError extends StorybookSvelteCSFError {
    readonly category: "PARSER_EXTRACT_SVELTE";
    readonly code = 9;
    documentation: boolean;
    constructor(options?: ConstructorParameters<typeof Error>[1]);
    template(): string;
}
