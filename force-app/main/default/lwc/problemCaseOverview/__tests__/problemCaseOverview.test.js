import { createElement } from 'lwc';
import ProblemCaseOverview from 'c/problemCaseOverview';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import getOverview from '@salesforce/apex/ProblemController.getOverview';
import searchCases from '@salesforce/apex/ProblemController.searchCases';
import linkCases from '@salesforce/apex/ProblemController.linkCases';
import closeOpenCases from '@salesforce/apex/ProblemController.closeOpenCases';

jest.mock(
    '@salesforce/apex/ProblemController.getOverview',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock('@salesforce/apex/ProblemController.searchCases', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ProblemController.linkCases', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ProblemController.closeOpenCases', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex', () => ({ refreshApex: jest.fn(() => Promise.resolve()) }), { virtual: true });
jest.mock('lightning/confirm', () => ({ open: jest.fn() }), { virtual: true });

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const CASES = [
    {
        caseId: '500A',
        caseNumber: '00001001',
        subject: 'Erro no login 0',
        status: 'New',
        accountName: 'Conta 0',
        createdDate: '2026-11-01T10:00:00.000Z',
        isClosed: false
    },
    {
        caseId: '500B',
        caseNumber: '00001002',
        subject: 'Erro no login 1',
        status: 'Closed',
        accountName: 'Conta 1',
        createdDate: '2026-11-02T10:00:00.000Z',
        isClosed: true
    }
];

const OVERVIEW = {
    totalCases: 2,
    openCases: 1,
    closedCases: 1,
    affectedCustomers: 2,
    canCloseCases: true,
    cases: CASES
};

const PROBLEM_ID = '0PR000000000001';

function mount() {
    const element = createElement('c-problem-case-overview', { is: ProblemCaseOverview });
    element.recordId = PROBLEM_ID;
    document.body.appendChild(element);
    return element;
}

function statValue(element, key) {
    return element.shadowRoot.querySelector('[data-stat="' + key + '"]').textContent;
}

function buttonWithLabel(element, text) {
    return [...element.shadowRoot.querySelectorAll('lightning-button')].find(
        (button) => button.label && button.label.startsWith(text)
    );
}

async function openSearchAndType(element, term) {
    buttonWithLabel(element, 'Vincular casos').click();
    await flushPromises();
    const input = element.shadowRoot.querySelector('lightning-input');
    input.dispatchEvent(new CustomEvent('change', { detail: { value: term } }));
    input.dispatchEvent(new CustomEvent('commit'));
    await flushPromises();
}

function selectFirstResult(element) {
    element.shadowRoot
        .querySelector('lightning-datatable.search-results')
        .dispatchEvent(new CustomEvent('rowselection', { detail: { selectedRows: [CASES[0]] } }));
}

describe('c-problem-case-overview', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('mostra os cards e a tabela com os casos vinculados', async () => {
        const element = mount();
        getOverview.emit(OVERVIEW);
        await flushPromises();

        expect(statValue(element, 'total')).toBe('2');
        expect(statValue(element, 'open')).toBe('1');
        expect(statValue(element, 'closed')).toBe('1');
        expect(statValue(element, 'customers')).toBe('2');
        const table = element.shadowRoot.querySelector('lightning-datatable.linked-cases');
        expect(table.data).toHaveLength(2);
        expect(buttonWithLabel(element, 'Fechar 1 caso aberto')).toBeTruthy();
    });

    it('esconde o botao de fechar quando o usuario nao pode fechar em lote', async () => {
        const element = mount();
        getOverview.emit({ ...OVERVIEW, canCloseCases: false });
        await flushPromises();

        expect(buttonWithLabel(element, 'Fechar')).toBeUndefined();
        expect(buttonWithLabel(element, 'Vincular casos')).toBeTruthy();
    });

    it('mostra mensagem quando nao ha casos vinculados', async () => {
        const element = mount();
        getOverview.emit({ ...OVERVIEW, totalCases: 0, openCases: 0, closedCases: 0, affectedCustomers: 0, cases: [] });
        await flushPromises();

        expect(element.shadowRoot.querySelector('.empty-message')).toBeTruthy();
        expect(element.shadowRoot.querySelector('lightning-datatable.linked-cases')).toBeNull();
    });

    it('mostra o erro do Apex ao carregar', async () => {
        const element = mount();
        getOverview.error({ message: 'Problema nao encontrado ou sem acesso.' });
        await flushPromises();

        expect(element.shadowRoot.querySelector('.error-message').textContent).toBe(
            'Problema nao encontrado ou sem acesso.'
        );
    });

    it('fecha os casos abertos depois da confirmacao e recarrega', async () => {
        LightningConfirm.open.mockResolvedValue(true);
        closeOpenCases.mockResolvedValue(1);
        const element = mount();
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);
        getOverview.emit(OVERVIEW);
        await flushPromises();

        buttonWithLabel(element, 'Fechar').click();
        await flushPromises();

        expect(LightningConfirm.open).toHaveBeenCalledTimes(1);
        expect(closeOpenCases).toHaveBeenCalledWith({ problemId: PROBLEM_ID });
        expect(refreshApex).toHaveBeenCalledTimes(1);
        expect(toastHandler.mock.calls[0][0].detail.variant).toBe('success');
    });

    it('nao fecha nada quando o usuario cancela a confirmacao', async () => {
        LightningConfirm.open.mockResolvedValue(false);
        const element = mount();
        getOverview.emit(OVERVIEW);
        await flushPromises();

        buttonWithLabel(element, 'Fechar').click();
        await flushPromises();

        expect(closeOpenCases).not.toHaveBeenCalled();
        expect(refreshApex).not.toHaveBeenCalled();
    });

    it('busca casos, vincula os selecionados e recarrega', async () => {
        searchCases.mockResolvedValue([CASES[0]]);
        linkCases.mockResolvedValue(1);
        const element = mount();
        getOverview.emit({ ...OVERVIEW, cases: [] });
        await flushPromises();

        await openSearchAndType(element, 'login');

        expect(searchCases).toHaveBeenCalledWith({ problemId: PROBLEM_ID, term: 'login' });
        expect(element.shadowRoot.querySelector('lightning-datatable.search-results').data).toHaveLength(1);

        selectFirstResult(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-button.link-button').click();
        await flushPromises();

        expect(linkCases).toHaveBeenCalledWith({ problemId: PROBLEM_ID, caseIds: ['500A'] });
        expect(refreshApex).toHaveBeenCalledTimes(1);
        expect(element.shadowRoot.querySelector('section[role="dialog"]')).toBeNull();
    });

    it('nao busca com termo menor que tres letras', async () => {
        const element = mount();
        getOverview.emit(OVERVIEW);
        await flushPromises();

        await openSearchAndType(element, 'lo');

        expect(searchCases).not.toHaveBeenCalled();
    });

    it('mostra aviso quando a busca nao encontra casos', async () => {
        searchCases.mockResolvedValue([]);
        const element = mount();
        getOverview.emit(OVERVIEW);
        await flushPromises();

        await openSearchAndType(element, 'inexistente');

        expect(element.shadowRoot.querySelector('.no-results')).toBeTruthy();
        expect(element.shadowRoot.querySelector('lightning-button.link-button').disabled).toBe(true);
    });

    it('mostra toast de erro quando o vinculo falha', async () => {
        searchCases.mockResolvedValue([CASES[0]]);
        linkCases.mockRejectedValue({ body: { message: 'Sem permissao.' } });
        const element = mount();
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);
        getOverview.emit(OVERVIEW);
        await flushPromises();

        await openSearchAndType(element, 'login');
        selectFirstResult(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-button.link-button').click();
        await flushPromises();

        const toast = toastHandler.mock.calls[0][0].detail;
        expect(toast.variant).toBe('error');
        expect(toast.message).toBe('Sem permissao.');
        expect(refreshApex).not.toHaveBeenCalled();
    });
});
