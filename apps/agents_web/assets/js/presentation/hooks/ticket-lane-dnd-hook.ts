const DRAG_TYPE = 'application/x-ticket-number'
const CLICK_SUPPRESS_MS = 200

type DndState = {
  draggedCard: HTMLElement | null
  draggedItem: HTMLElement | null
}

function collectLaneOrder(el: HTMLElement): string[] {
  return Array.from(el.querySelectorAll<HTMLElement>('[data-ticket-card]')).map((node) =>
    node.dataset.ticketNumber || ''
  )
}

function cardContainer(card: HTMLElement): HTMLElement | null {
  return card.closest<HTMLElement>('[data-ticket-item]')
}

export const TicketLaneDndHook = {
  dndState: { draggedCard: null, draggedItem: null } as DndState,
  suppressClickUntil: 0,

  mounted() {
    this.bindTicketCards()

    this.el.addEventListener('dragover', (event: DragEvent) => {
      event.preventDefault()
      if (event.dataTransfer) event.dataTransfer.dropEffect = 'move'
    })

    this.el.addEventListener('dragenter', (event: DragEvent) => {
      event.preventDefault()
    })

    this.el.addEventListener('drop', (event: DragEvent) => {
      event.preventDefault()
      event.stopPropagation()

      const movedNumber = event.dataTransfer?.getData(DRAG_TYPE)
      const sourceLane = event.dataTransfer?.getData('application/x-ticket-lane')
      const targetLane = this.el.dataset.ticketLane || ''

      if (!movedNumber) return

      const draggedCard =
        this.dndState.draggedCard ||
        document.querySelector<HTMLElement>(`[data-ticket-card][data-ticket-number="${movedNumber}"]`)
      const dragged = this.dndState.draggedItem || (draggedCard && cardContainer(draggedCard))
      if (!dragged) return

      const dropTargetCard = (event.target as HTMLElement)?.closest<HTMLElement>('[data-ticket-card]')
      const dropTarget = dropTargetCard && cardContainer(dropTargetCard)

      if (dropTarget && dropTarget !== dragged) {
        const dropRect = dropTarget.getBoundingClientRect()
        const insertBefore = (event.clientY || 0) < dropRect.top + dropRect.height / 2

        if (insertBefore) {
          dropTarget.parentElement?.insertBefore(dragged, dropTarget)
        } else {
          dropTarget.parentElement?.insertBefore(dragged, dropTarget.nextElementSibling)
        }
      } else {
        this.el.appendChild(dragged)
      }

      const orderedNumbers = collectLaneOrder(this.el)
      this.suppressClickUntil = Date.now() + CLICK_SUPPRESS_MS

      this.pushEvent('reorder_tickets', {
        moved_number: movedNumber,
        source_status: sourceLane,
        target_status: targetLane,
        ordered_numbers: orderedNumbers
      })

      if (draggedCard) draggedCard.classList.remove('opacity-70')
      this.dndState.draggedCard = null
      this.dndState.draggedItem = null
    })
  },

  updated() {
    this.bindTicketCards()
  },

  bindTicketCards() {
    const lane = this.el.dataset.ticketLane || ''

    this.el.querySelectorAll<HTMLElement>('[data-ticket-card]').forEach((card) => {
      card.draggable = true

      if (card.dataset.dndBound === 'true') return
      card.dataset.dndBound = 'true'

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
        event.dataTransfer?.setData('application/x-ticket-lane', lane)
        if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
      })

      card.addEventListener('dragend', () => {
        card.classList.remove('opacity-70')
        this.dndState.draggedCard = null
        this.dndState.draggedItem = null
      })
    })
  }
}
