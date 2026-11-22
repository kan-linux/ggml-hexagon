import { StorybookSvelteCSFError } from '../../error.js';
import type { SvelteAST } from '../../../parser/ast.js';
export declare class InvalidTemplateAttribute extends StorybookSvelteCSFError {
    readonly category: "LEGACY_API";
    readonly code = 1;
    documentation: boolean;
    attribute: SvelteAST.Attribute;
    constructor({ filename, attribute, }: {
        filename: StorybookSvelteCSFError['filename'];
        attribute: InvalidTemplateAttribute['attribute'];
    });
    template(): string;
}
export declare class LegacyTemplateNotEnabledError extends StorybookSvelteCSFError {
    readonly category: "LEGACY_API";
    readonly code = 2;
    documentation: boolean;
    constructor(filename?: string, options?: ConstructorParameters<typeof Error>[1]);
    template(): string;
}
export declare class DuplicatedUnidentifiedTemplateError extends StorybookSvelteCSFError {
    readonly category: "LEGACY_API";
    readonly code = 3;
    documentation: boolean;
    constructor(filename?: string);
    template(): string;
}
