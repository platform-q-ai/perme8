// Intersection Observer for Collaborative Editor Animations
// Triggers animations when the section scrolls into view

export const observeCollabEditor = () => {
  const collabSection = document.querySelector('[data-collab-editor-section]');

  if (!collabSection) return;

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      const editorDiv = entry.target.querySelector('.collab-editor-animations-paused');

      if (entry.isIntersecting && editorDiv) {
        // Start animations when section is visible
        editorDiv.classList.remove('collab-editor-animations-paused');
        editorDiv.classList.add('collab-editor-animations-active');

        // Optionally, stop observing after first activation
        // observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.3, // Trigger when 30% of the section is visible
    rootMargin: '0px'
  });

  observer.observe(collabSection);
};
