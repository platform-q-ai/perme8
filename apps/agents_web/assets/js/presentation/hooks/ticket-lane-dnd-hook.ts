const DRAG_TYPE = 'application/x-ticket-number'

function collectLaneOrder(el: HTMLElement): string[] {
  return Array.from(el.querySelectorAll<HTMLElement>('[data-ticket-card]')).map((node) =>
    node.dataset.ticketNumber || ''
  )
}

function cardContainer(card: HTMLElement): HTMLElement | null {
  return card.closest<HTMLElement>('[data-ticket-item]')
}

export const TicketLaneDndHook = {
  mounted() {
    this.bindTicketCards()

    this.el.addEventListener('dragover', (event: DragEvent) => {
      event.preventDefault()
    })

    this.el.addEventListener('drop', (event: DragEvent) => {
      event.preventDefault()

      const movedNumber = event.dataTransfer?.getData(DRAG_TYPE)
      const sourceLane = event.dataTransfer?.getData('application/x-ticket-lane')
      const targetLane = this.el.dataset.ticketLane || ''

      if (!movedNumber) return

      const draggedCard = document.querySelector<HTMLElement>(`[data-ticket-card][data-ticket-number="${movedNumber}"]`)
      const dragged = draggedCard && cardContainer(draggedCard)
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

      this.pushEvent('reorder_tickets', {
        moved_number: movedNumber,
        source_status: sourceLane,
        target_status: targetLane,
        ordered_numbers: orderedNumbers
      })
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

      card.addEventListener('dragstart', (event: DragEvent) => {
        const number = card.dataset.ticketNumber
        if (!number) return

        event.dataTransfer?.setData(DRAG_TYPE, number)
        event.dataTransfer?.setData('application/x-ticket-lane', lane)
        event.dataTransfer!.effectAllowed = 'move'
      })
    })
  }
}
