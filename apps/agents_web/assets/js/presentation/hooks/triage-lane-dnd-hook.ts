/**
 * TriageLaneDnd — local-only drag-and-drop for ticket cards in the triage lane.
 *
 * Only operates on elements marked with `data-triage-ticket-card`.
 * Sends `reorder_triage_tickets` events to the LiveView with the new
 * ordered list of ticket numbers. Position is managed entirely in the
 * LiveView assign — no GitHub sync is performed.
 */

const DRAG_TYPE = 'application/x-triage-ticket-number'
const CLICK_SUPPRESS_MS = 200

type DndState = {
  draggedCard: HTMLElement | null
  draggedItem: HTMLElement | null
}

function collectTicketOrder(el: HTMLElement): string[] {
  return Array.from(el.querySelectorAll<HTMLElement>('[data-triage-ticket-card]')).map(
    (node) => node.dataset.ticketNumber || ''
  )
}

function cardContainer(card: HTMLElement): HTMLElement | null {
  return card.closest<HTMLElement>('[data-triage-ticket-item]')
}

export const TriageLaneDndHook = {
  dndState: { draggedCard: null, draggedItem: null } as DndState,
  suppressClickUntil: 0,

  mounted() {
    this.bindTriageTicketCards()

    this.el.addEventListener('dragover', (event: DragEvent) => {
      if (!event.dataTransfer?.types.includes(DRAG_TYPE)) return
      event.preventDefault()
      if (event.dataTransfer) event.dataTransfer.dropEffect = 'move'
    })

    this.el.addEventListener('dragenter', (event: DragEvent) => {
      if (!event.dataTransfer?.types.includes(DRAG_TYPE)) return
      event.preventDefault()
    })

    this.el.addEventListener('drop', (event: DragEvent) => {
      const movedNumber = event.dataTransfer?.getData(DRAG_TYPE)
      if (!movedNumber) return

      event.preventDefault()
      event.stopPropagation()

      const draggedCard =
        this.dndState.draggedCard ||
        this.el.querySelector<HTMLElement>(
          `[data-triage-ticket-card][data-ticket-number="${movedNumber}"]`
        )
      const dragged = this.dndState.draggedItem || (draggedCard && cardContainer(draggedCard))
      if (!dragged) return

      const dropTargetCard = (event.target as HTMLElement)?.closest<HTMLElement>(
        '[data-triage-ticket-card]'
      )
      const dropTarget = dropTargetCard && cardContainer(dropTargetCard)

      if (dropTarget && dropTarget !== dragged) {
        const dropRect = dropTarget.getBoundingClientRect()
        const insertBefore = (event.clientY || 0) < dropRect.top + dropRect.height / 2

        if (insertBefore) {
          dropTarget.parentElement?.insertBefore(dragged, dropTarget)
        } else {
          dropTarget.parentElement?.insertBefore(dragged, dropTarget.nextElementSibling)
        }
      } else if (!dropTarget) {
        // Dropped on empty area at the end — append
        const lastTicketItem = Array.from(
          this.el.querySelectorAll<HTMLElement>('[data-triage-ticket-item]')
        ).pop()
        if (lastTicketItem && lastTicketItem !== dragged) {
          lastTicketItem.parentElement?.insertBefore(dragged, lastTicketItem.nextElementSibling)
        }
      }

      const orderedNumbers = collectTicketOrder(this.el)
      this.suppressClickUntil = Date.now() + CLICK_SUPPRESS_MS

      this.pushEvent('reorder_triage_tickets', {
        ordered_numbers: orderedNumbers,
      })

      if (draggedCard) draggedCard.classList.remove('opacity-70')
      this.dndState.draggedCard = null
      this.dndState.draggedItem = null
    })
  },

  updated() {
    this.bindTriageTicketCards()
  },

  bindTriageTicketCards() {
    this.el.querySelectorAll<HTMLElement>('[data-triage-ticket-card]').forEach((card) => {
      card.draggable = true

      if (card.dataset.triageDndBound === 'true') return
      card.dataset.triageDndBound = 'true'

      card.addEventListener(
        'click',
        (event: MouseEvent) => {
          if (Date.now() < this.suppressClickUntil) {
            event.preventDefault()
            event.stopPropagation()
          }
        },
        true
      )

      card.addEventListener('dragstart', (event: DragEvent) => {
        const number = card.dataset.ticketNumber
        if (!number) return

        const item = cardContainer(card)
        this.dndState.draggedCard = card
        this.dndState.draggedItem = item
        card.classList.add('opacity-70')

        event.dataTransfer?.setData(DRAG_TYPE, number)
        event.dataTransfer?.setData('text/plain', number)
        if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
      })

      card.addEventListener('dragend', () => {
        card.classList.remove('opacity-70')
        this.dndState.draggedCard = null
        this.dndState.draggedItem = null
      })
    })
  },
}
