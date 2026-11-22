import pkg from '@storybook/addon-svelte-csf/package.json' with { type: 'json' };
import { StorybookSvelteCSFError } from '../../error.js';
import dedent from 'dedent';
export class InvalidTemplateAttribute extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.legacyAPI;
    code = 1;
    documentation = true;
    attribute;
    constructor({ filename, attribute, }) {
        super({ filename });
        this.attribute = attribute;
    }
    template() {
        return dedent `
      'Story' component prop 'template' value must be a string with a reference to existing '<Template>' component id.

      The issue occurred in Stories file: ${this.filepathURL}
    `;
    }
}
export class LegacyTemplateNotEnabledError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.legacyAPI;
    code = 2;
    documentation = true;
    constructor(filename, options) {
        super({ filename });
        this.cause = options?.cause;
    }
    template() {
        return dedent `
      Stories file: ${this.filename}
      is using legacy API.

      To enable support for it, enable 'legacyTemplate' in "${pkg.name}" option.
    `;
    }
}
export class DuplicatedUnidentifiedTemplateError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.legacyAPI;
    code = 3;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
      Stories file: ${this.filename}
      has two '<Template />' components without provided prop 'id'. This leads to unwanted runtime behavior.

      Please provide an 'id' to one of them.
      And for the '<Story />' component(s) which are supposed to use it, add the 'template' prop with the same 'id' value.
    `;
    }
}
