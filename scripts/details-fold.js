/**
 * Dynamic details folding helper for LLM Agents Workshop.
 * 
 * Automatically initializes teaser previews by duplicating the teaser text 
 * into a selectable paragraph inside the details body at runtime.
 * This resolves text selection and click-to-close issues natively 
 * across dynamic page navigations.
 */
document.addEventListener("DOMContentLoaded", function() {
  function initTeasers() {
    document.querySelectorAll('details').forEach(function(details) {
      const summary = details.querySelector('summary');
      if (!summary) return;
      
      const teaser = summary.querySelector('.teaser-preview');
      if (!teaser) return;
      
      // If already initialized, skip
      if (details.querySelector('.teaser-body')) return;
      
      // Dynamically clone the teaser preview into a selectable p inside the details body
      const bodyCopy = document.createElement('p');
      bodyCopy.className = 'teaser-body';
      bodyCopy.textContent = teaser.textContent;
      
      // Insert it immediately after the summary element
      summary.insertAdjacentElement('afterend', bodyCopy);
    });
  }
  
  function initPdfLink() {
    const marginSidebar = document.querySelector('#quarto-margin-sidebar');
    if (marginSidebar && !marginSidebar.querySelector('.quarto-margin-pdf-link')) {
      const pdfLinkDiv = document.createElement('div');
      pdfLinkDiv.className = 'quarto-margin-pdf-link';
      pdfLinkDiv.style.display = 'flex';
      pdfLinkDiv.style.flexDirection = 'column';
      pdfLinkDiv.style.gap = '10px';
      pdfLinkDiv.innerHTML = `
        <a href="assets/Beyond-the-Chatbox.pdf" target="_blank">
          <i class="bi bi-file-earmark-pdf-fill"></i>
          <span>Download full tutorial as PDF</span>
        </a>
        <a href="slides/slides.pdf" target="_blank">
          <i class="bi bi-file-earmark-pdf-fill"></i>
          <span>Download slides as PDF</span>
        </a>
      `;
      marginSidebar.insertBefore(pdfLinkDiv, marginSidebar.firstChild);
    }
  }
  
  initTeasers();
  initPdfLink();
  
  // Watch for DOM changes to automatically support dynamic page navigations (SPA)
  new MutationObserver(function() {
    initTeasers();
    initPdfLink();
  }).observe(document.body, {
    childList: true,
    subtree: true
  });
});
