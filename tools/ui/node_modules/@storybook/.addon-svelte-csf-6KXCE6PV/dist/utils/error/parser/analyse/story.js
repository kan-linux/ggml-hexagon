import dedent from 'dedent';
import { StorybookSvelteCSFError } from '../../../error.js';
export class AttributeNotStringError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 1;
    documentation = true;
    attribute;
    constructor({ filename, attribute, component, }) {
        super({ component, filename });
        this.attribute = attribute;
    }
    template() {
        return dedent `
      In the stories file: ${this.filepathURL}

      A '${this.quickStoryRawCodeIdentifier}' has a prop '${this.attribute.name}' whose value must be a static literal string.
    `;
    }
}
export class AttributeNotArrayError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 2;
    documentation = true;
    attribute;
    constructor({ filename, attribute, component, }) {
        super({ component, filename });
        this.attribute = attribute;
    }
    get valueType() {
        const { attribute } = this;
        const { value } = attribute;
        if (value === true) {
            return true;
        }
        // value is SvelteAST.ExpressionTag
        if (!Array.isArray(value)) {
            return value.expression.value;
        }
        if (value[0].type === 'Text') {
            return value[0].data;
        }
        return value[0].expression.value;
    }
    template() {
        return dedent `
      In the stories file: ${this.filepathURL}

      A '${this.quickStoryRawCodeIdentifier}' has a prop'${this.attribute.name}' whose value was expected to be a static array.
      Instead the value type is '${this.valueType}'.
    `;
    }
}
export class AttributeNotArrayOfStringsError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 3;
    documentation = true;
    attribute;
    element;
    constructor({ filename, attribute, component, element, }) {
        super({ component, filename });
        this.attribute = attribute;
        this.element = element;
    }
    get valueType() {
        const { attribute } = this;
        const { value } = attribute;
        if (value === true) {
            return true;
        }
        if (!Array.isArray(value)) {
            return value.expression.value;
        }
        if (value[0].type === 'Text') {
            return value[0].data;
        }
        return value[0].expression.value;
    }
    template() {
        return dedent `
      In the stories file: ${this.filepathURL}

      A '${this.quickStoryRawCodeIdentifier}' has attribute '${this.attribute.name}' whose value was expected to be an array expression.
      All elements in the array must be static literal strings only, but one of the elements is of type '${this.valueType}'.
    `;
    }
}
export class NoStoryIdentifierError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 4;
    documentation = true;
    constructor({ filename, component, }) {
        super({ component, filename });
    }
    template() {
        return dedent `
        Missing 'name' or 'exportName' attribute (prop) in a '<Story />' definition in the stories file:  '${this.filepathURL}'.
        All stories must either have a 'name' or an 'exportName' prop, or both.
    `;
    }
}
export class InvalidStoryExportNameError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 5;
    documentation = true;
    value;
    constructor({ filename, component, value, }) {
        super({ component, filename });
        this.value = value;
    }
    template() {
        return dedent `
		Invalid attribute 'exportName' value '${this.value}' found in '<Story />' component inside stories file: ${this.filepathURL}

    'exportName' value must be a valid JavaScript variable name.
    It must start with a letter, $ or _, followed by letters, numbers, $ or _.
    Reserved words like 'default' are also not allowed (see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Lexical_grammar#reserved_words)
    `;
    }
}
export class DuplicateStoryIdentifiersError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 6;
    documentation = true;
    identifiers;
    duplicateIdentifiers;
    constructor({ filename, identifiers, duplicateIdentifiers, }) {
        super({ filename });
        this.identifiers = identifiers;
        this.duplicateIdentifiers = duplicateIdentifiers;
    }
    template() {
        return dedent `
      Duplicate exportNames found between two '<Story />' definitions in stories file: ${this.filepathURL}

      First instance: <Story name=${this.duplicateIdentifiers.name ? `"${this.duplicateIdentifiers.name}"` : '{undefined}'} exportName="${this.duplicateIdentifiers.exportName}" ... />
      Second instance: <Story name=${this.identifiers.name ? `"${this.identifiers.name}"` : '{undefined}'} exportName="${this.identifiers.exportName}" ... />

      This can happen when 'exportName' is implicitly derived by 'name'.
      Complex names will be simplified to a PascalCased, valid JavaScript variable name,
      eg. 'Some story name!!' will be converted to 'SomeStoryName'.
      You can fix this collision by providing a unique 'exportName' prop with <Story exportName="SomeUniqueExportName" ... />.
    `;
    }
}
export class StoryTemplateAndChildrenError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 7;
    documentation = true;
    constructor({ filename, component, }) {
        super({ component, filename });
    }
    template() {
        return dedent `
      A '${this.quickStoryRawCodeIdentifier}' has both a 'template' prop and children elements defined, which is not allowed.
      Use the 'template' snippet to define the story's content structure.
      Found in file: ${this.filepathURL}
    `;
    }
}
export class StoryTemplateAndAsChildError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 8;
    documentation = true;
    constructor({ filename, component, }) {
        super({ component, filename });
    }
    template() {
        return dedent `
      A '${this.quickStoryRawCodeIdentifier}' has both a 'template' prop and the 'asChild' prop set.
      Use the 'template' snippet to define the story's content structure.
      Found in file: ${this.filepathURL}
    `;
    }
}
export class StoryAsChildWithoutChildrenError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserAnalyseStory;
    code = 9;
    documentation = true;
    constructor({ filename, component, }) {
        super({ component, filename });
    }
    template() {
        return dedent `
      A '${this.quickStoryRawCodeIdentifier}' has the 'asChild' prop set, but no children were provided. The 'asChild' prop requires children to render the story content.
      Found in file: ${this.filepathURL}
    `;
    }
}
