import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getOverview from '@salesforce/apex/ProblemController.getOverview';
import searchCases from '@salesforce/apex/ProblemController.searchCases';
import linkCases from '@salesforce/apex/ProblemController.linkCases';
import closeOpenCases from '@salesforce/apex/ProblemController.closeOpenCases';

const MIN_TERM_LENGTH = 3;
const GENERIC_ERROR = 'Não foi possível concluir a ação. Tente novamente.';

const CASE_COLUMNS = [
    { label: 'Número', fieldName: 'caseNumber', type: 'text', initialWidth: 110 },
    { label: 'Assunto', fieldName: 'subject', type: 'text' },
    { label: 'Conta', fieldName: 'accountName', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 120 },
    {
        label: 'Aberto em',
        fieldName: 'createdDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' },
        initialWidth: 120
    }
];

function plural(count, singular, pluralForm) {
    return count === 1 ? singular : pluralForm;
}

function extractMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    if (error && typeof error.message === 'string') {
        return error.message;
    }
    return GENERIC_ERROR;
}

export default class ProblemCaseOverview extends LightningElement {
    @api recordId;

    overview;
    errorMessage;
    isWorking = false;
    isSearchOpen = false;
    hasSearched = false;
    searchTerm = '';
    searchResults = [];
    selectedCaseIds = [];
    wiredOverview;

    columns = CASE_COLUMNS;
    searchColumns = CASE_COLUMNS;

    @wire(getOverview, { problemId: '$recordId' })
    handleOverview(result) {
        this.wiredOverview = result;
        if (result.data) {
            this.overview = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.overview = undefined;
            this.errorMessage = extractMessage(result.error);
        }
    }

    get isBusy() {
        return this.isWorking || (!this.overview && !this.errorMessage);
    }

    get stats() {
        const data = this.overview || {};
        return [
            { key: 'total', label: 'Casos vinculados', value: data.totalCases || 0 },
            { key: 'open', label: 'Abertos', value: data.openCases || 0 },
            { key: 'closed', label: 'Fechados', value: data.closedCases || 0 },
            { key: 'customers', label: 'Clientes afetados', value: data.affectedCustomers || 0 }
        ];
    }

    get hasCases() {
        return !!this.overview && this.overview.cases.length > 0;
    }

    get showCloseButton() {
        return !!this.overview && this.overview.canCloseCases && this.overview.openCases > 0;
    }

    get openCount() {
        return this.overview ? this.overview.openCases : 0;
    }

    get closeLabel() {
        return 'Fechar ' + this.openCount + ' ' + plural(this.openCount, 'caso aberto', 'casos abertos');
    }

    get hasSearchResults() {
        return this.searchResults.length > 0;
    }

    get cannotLink() {
        return this.isWorking || this.selectedCaseIds.length === 0;
    }

    get linkLabel() {
        const count = this.selectedCaseIds.length;
        return count > 0 ? 'Vincular ' + count : 'Vincular';
    }

    openSearch() {
        this.isSearchOpen = true;
        this.hasSearched = false;
        this.searchTerm = '';
        this.searchResults = [];
        this.selectedCaseIds = [];
    }

    closeSearch() {
        this.isSearchOpen = false;
    }

    handleTermChange(event) {
        this.searchTerm = event.detail.value || '';
    }

    async runSearch() {
        const term = this.searchTerm.trim();
        if (term.length < MIN_TERM_LENGTH) {
            this.searchResults = [];
            this.hasSearched = false;
            return;
        }
        this.isWorking = true;
        try {
            this.searchResults = await searchCases({ problemId: this.recordId, term });
            this.selectedCaseIds = [];
            this.hasSearched = true;
        } catch (error) {
            this.toast('Erro na busca', extractMessage(error), 'error');
        } finally {
            this.isWorking = false;
        }
    }

    handleSelection(event) {
        this.selectedCaseIds = event.detail.selectedRows.map((row) => row.caseId);
    }

    async linkSelected() {
        if (this.selectedCaseIds.length === 0) {
            return;
        }
        this.isWorking = true;
        try {
            const linked = await linkCases({ problemId: this.recordId, caseIds: this.selectedCaseIds });
            this.toast('Casos vinculados', linked + ' ' + plural(linked, 'caso vinculado', 'casos vinculados') + ' ao problema.', 'success');
            this.closeSearch();
            await refreshApex(this.wiredOverview);
        } catch (error) {
            this.toast('Erro ao vincular', extractMessage(error), 'error');
        } finally {
            this.isWorking = false;
        }
    }

    async confirmClose() {
        const open = this.openCount;
        const confirmed = await LightningConfirm.open({
            label: 'Fechar casos em lote',
            message: 'Fechar ' + open + ' ' + plural(open, 'caso aberto', 'casos abertos') + ' vinculados a este problema? A resolução padrão será registrada em cada caso.',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }
        this.isWorking = true;
        try {
            const closed = await closeOpenCases({ problemId: this.recordId });
            this.toast('Casos fechados', closed + ' ' + plural(closed, 'caso fechado', 'casos fechados') + '.', 'success');
            await refreshApex(this.wiredOverview);
        } catch (error) {
            this.toast('Erro ao fechar', extractMessage(error), 'error');
        } finally {
            this.isWorking = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
