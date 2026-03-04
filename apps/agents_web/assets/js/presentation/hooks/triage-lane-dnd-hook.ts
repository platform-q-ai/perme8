/**
 * TriageLaneDnd — local-only drag-and-drop for ticket cards in the triage lane.
 *
 * Only operates on elements marked with `data-triage-ticket-card`.
 * Sends `reorder_triage_tickets` events to the LiveView with the new
 * ordered list of ticket numbers. Position is managed entirely in the
 * LiveView assign — no GitHub sync is performed.
 *
 * Uses a pointer-movement threshold (DRAG_THRESHOLD_PX) before enabling
 * the native drag so that simple clicks are never swallowed by the
 * browser's drag subsystem.
 */

const DRAG_TYPE = 'application/x-triage-ticket-number'
const DRAG_THRESHOLD_PX = 6

type DndState = {
  draggedCard: HTMLElement | null
  draggedItem: HTMLElement | null
}

type PendingDrag = {
  card: HTMLElement
  startX: number
  startY: number
  onMove: (e: PointerEvent) => void
  onUp: (e: PointerEvent) => void
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
  pendingDrag: null as PendingDrag | null,
  isDragging: false,

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

      this.pushEvent('reorder_triage_tickets', {
        ordered_numbers: orderedNumbers,
      })

      if (draggedCard) draggedCard.classList.remove('opacity-70')
      this.dndState.draggedCard = null
      this.dndState.draggedItem = null
      this.isDragging = false
    })
  },

  updated() {
    this.bindTriageTicketCards()
  },

  cleanupPendingDrag() {
    if (this.pendingDrag) {
      document.removeEventListener('pointermove', this.pendingDrag.onMove)
      document.removeEventListener('pointerup', this.pendingDrag.onUp)
      this.pendingDrag = null
    }
  },

  bindTriageTicketCards() {
    this.el.querySelectorAll<HTMLElement>('[data-triage-ticket-card]').forEach((card) => {
      // Cards start NOT draggable — we enable it only after threshold
      card.draggable = false

      if (card.dataset.triageDndBound === 'true') return
      card.dataset.triageDndBound = 'true'

      card.addEventListener(
        'click',
        (event: MouseEvent) => {
          if (this.isDragging) {
            event.preventDefault()
            event.stopPropagation()
            this.isDragging = false
          }
        },
        true
      )

      card.addEventListener('pointerdown', (event: PointerEvent) => {
        // Only primary button
        if (event.button !== 0) return

        this.cleanupPendingDrag()

        const startX = event.clientX
        const startY = event.clientY

        const onMove = (moveEvent: PointerEvent) => {
          const dx = moveEvent.clientX - startX
          const dy = moveEvent.clientY - startY

          if (Math.abs(dx) + Math.abs(dy) >= DRAG_THRESHOLD_PX) {
            // Threshold exceeded — enable native drag and clean up
            card.draggable = true
            this.isDragging = true
            this.cleanupPendingDrag()
          }
        }

        const onUp = () => {
          // Mouse released without meeting threshold — it's a click
          this.cleanupPendingDrag()
          // draggable stays false so the next click won't be swallowed
        }

        this.pendingDrag = { card, startX, startY, onMove, onUp }
        document.addEventListener('pointermove', onMove)
        document.addEventListener('pointerup', onUp)
      })

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
        card.draggable = false
        this.dndState.draggedCard = null
        this.dndState.draggedItem = null
        this.isDragging = false
      })
    })
  },
}
