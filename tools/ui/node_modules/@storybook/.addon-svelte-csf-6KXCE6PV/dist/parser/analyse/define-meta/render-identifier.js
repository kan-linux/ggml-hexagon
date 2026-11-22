import { extractDefineMetaPropertiesNodes } from '../../extract/svelte/define-meta.js';
import { InvalidRenderValueError } from '../../../utils/error/parser/analyse/define-meta.js';
export function getDefineMetaRenderValue(params) {
    const { nodes, filename } = params;
    const { render } = extractDefineMetaPropertiesNodes({
        nodes,
        properties: ['render'],
    });
    if (!render) {
        return;
    }
    const { value } = render;
    if (value.type !== 'Identifier') {
        throw new InvalidRenderValueError({
            filename,
            renderProperty: render,
        });
    }
    return value;
}
