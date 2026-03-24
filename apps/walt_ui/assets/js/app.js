// If you want to use Phoenix channels, run `mix help phx.gen.channel` to get started and then uncomment the line below.
// import "./user_socket.js"

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import alpine from "alpinejs"
import posthog from "posthog-js"
import topbar from "topbar";

// Initialize alpine.js
alpine.start();

// LiveView hooks
let Hooks = {};

// Copy to clipboard hook
Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("walt:copy-to-clipboard", async (e) => {
      const text = e.detail.text;
      try {
        await navigator.clipboard.writeText(text);
        this.pushEvent("show-flash", {
          type: "info",
          message: `User ID copied to clipboard: ${text.substring(0, 8)}...`
        });
      } catch (err) {
        console.error('Failed to copy text: ', err);
        this.pushEvent("show-flash", {
          type: "error", 
          message: "Failed to copy to clipboard"
        });
      }
    });
  }
};

// Auto-hide flash messages after a delay
Hooks.FlashAutoHide = {
  mounted() {
    // Auto-hide after 2.5 seconds
    setTimeout(() => {
      if (this.el.style.display !== 'none') {
        this.el.click(); // Trigger the existing click handler to hide the flash
      }
    }, 2500);
  },
  updated() {
    // Re-trigger auto-hide when flash is updated (new message)
    setTimeout(() => {
      if (this.el.style.display !== 'none') {
        this.el.click();
      }
    }, 2500);
  }
};

// Infinite scroll hook for paginated lists
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (entry.isIntersecting) {
          this.pushEvent("load-more", {});
        }
      },
      { rootMargin: "200px" }
    );
    this.observer.observe(this.el);
  },
  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
};

// Scroll position restoration hook
Hooks.ScrollRestore = {
  mounted() {
    this.currentPage = 1; // Track actual current page

    // Check if we need to restore scroll position
    const savedPosition = sessionStorage.getItem('contacts-scroll-position');
    const savedPage = sessionStorage.getItem('contacts-current-page');

    if (savedPosition && savedPage) {
      // Send event to LiveView to load the required pages first
      this.pushEvent('restore-scroll', {
        position: parseInt(savedPosition),
        page: parseInt(savedPage)
      });

      // Clear the saved state
      sessionStorage.removeItem('contacts-scroll-position');
      sessionStorage.removeItem('contacts-current-page');
    }

    // Listen for page changes from LiveView
    this.handleEvent('page-changed', ({page}) => {
      this.currentPage = page;
    });

    // Listen for restore confirmation from LiveView
    this.handleEvent('scroll-restored', ({position}) => {
      setTimeout(() => {
        window.scrollTo(0, position);
      }, 100); // Small delay to ensure content is rendered
    });

    // Save scroll position when leaving page
    window.addEventListener('beforeunload', () => {
      this.saveScrollState();
    });
  },

  saveScrollState() {
    sessionStorage.setItem('contacts-scroll-position', window.scrollY);
    // Use actual tracked page number instead of estimation
    sessionStorage.setItem('contacts-current-page', this.currentPage || 1);
  },

  destroyed() {
    // Save scroll position when LiveView unmounts
    this.saveScrollState();
  }
};

// Contact animations hook
Hooks.ContactAnimations = {
  mounted() {
    this.animatedContactIds = new Set();
    this.animatedPTTCircles = new Set();
    this.animateInitialLoad();
  },

  updated() {
    this.animateNewContacts();
  },

  animateInitialLoad() {
    const contactRows = this.el.querySelectorAll('.contact-row');
    const pttCircles = this.el.querySelectorAll('.ptt-circle');

    // Track all initial contacts as animated
    contactRows.forEach(row => {
      const contactId = row.getAttribute('data-contact-id');
      if (contactId) {
        this.animatedContactIds.add(contactId);

        // Also track PTT circles for initial contacts
        const pttCircle = row.querySelector('.ptt-circle');
        if (pttCircle) {
          this.animatedPTTCircles.add(`${contactId}-ptt`);
        }
      }
    });

    // Initially hide all contact rows
    contactRows.forEach(row => {
      row.style.opacity = '0';
      row.style.transform = 'translateY(20px)';
    });

    // Animate contact rows fading in
    contactRows.forEach((row, index) => {
      setTimeout(() => {
        row.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
        row.style.opacity = '1';
        row.style.transform = 'translateY(0)';
      }, index * 30);
    });

    // Start PTT circles much earlier and with faster stagger
    setTimeout(() => {
      this.animatePTTCircles(pttCircles);
    }, 100);
  },

  animateNewContacts() {
    // Use requestAnimationFrame to ensure DOM is ready
    requestAnimationFrame(() => {
      const allContactRows = this.el.querySelectorAll('.contact-row');
      const newContactRows = [];
      const newPTTCircles = [];

      // Find contacts that are truly new based on their IDs
      allContactRows.forEach(row => {
        const contactId = row.getAttribute('data-contact-id');

        if (contactId && !this.animatedContactIds.has(contactId)) {
          // This is a genuinely new contact
          this.animatedContactIds.add(contactId);
          newContactRows.push(row);

          // Find PTT circles in this new row
          const pttCircle = row.querySelector('.ptt-circle');
          if (pttCircle) {
            newPTTCircles.push(pttCircle);
          }
        } else if (contactId) {
          // This is an existing contact that got re-rendered - keep it visible
          row.style.opacity = '1';
          row.style.transform = 'translateY(0)';

          // Handle PTT circle for existing contact
          const pttCircle = row.querySelector('.ptt-circle');
          if (pttCircle) {
            const pttCircleId = `${contactId}-ptt`;

            if (this.animatedPTTCircles.has(pttCircleId)) {
              // This PTT circle was already animated - set its final state immediately
              this.setPTTFinalState(pttCircle);
            } else {
              // First time seeing this PTT circle, but contact existed - animate it
              this.animatedPTTCircles.add(pttCircleId);
              newPTTCircles.push(pttCircle);
            }
          }
        }
      });

      // If no new contacts, don't do anything
      if (newContactRows.length === 0) {
        return;
      }

      // Animate only the truly new contact rows
      newContactRows.forEach((row, index) => {
        // Set initial state for animation
        row.style.opacity = '0';
        row.style.transform = 'translateY(10px)';
        row.style.transition = 'opacity 0.2s ease, transform 0.2s ease';

        // Start animation immediately with minimal stagger
        setTimeout(() => {
          row.style.opacity = '1';
          row.style.transform = 'translateY(0)';
        }, index * 15);
      });

      // Start PTT circles much sooner
      setTimeout(() => {
        newPTTCircles.forEach((circle, index) => {
          setTimeout(() => {
            this.animateSinglePTTCircle(circle);
          }, index * 60);
        });
      }, 50);
    });
  },

  animatePTTCircles(circles) {
    circles.forEach((circle, index) => {
      setTimeout(() => {
        this.animateSinglePTTCircle(circle);
      }, index * 80);
    });
  },

  setPTTFinalState(circle) {
    const progressPath = circle.querySelector('.ptt-circle-progress');
    const textElement = circle.querySelector('.ptt-circle-text');
    const targetProgress = progressPath.getAttribute('data-target-progress');
    const targetScore = parseFloat(textElement.getAttribute('data-target-score'));

    // Set final state immediately without animation
    progressPath.style.strokeDasharray = targetProgress;
    progressPath.style.transition = 'none';
    textElement.textContent = targetScore.toFixed(1);
    textElement.style.color = '#6366f1';
  },

  animateSinglePTTCircle(circle) {
    const progressPath = circle.querySelector('.ptt-circle-progress');
    const textElement = circle.querySelector('.ptt-circle-text');
    const targetProgress = progressPath.getAttribute('data-target-progress');
    const targetScore = parseFloat(textElement.getAttribute('data-target-score'));

    // Find the contact ID for tracking
    const contactRow = circle.closest('.contact-row');
    const contactId = contactRow ? contactRow.getAttribute('data-contact-id') : null;

    if (contactId) {
      this.animatedPTTCircles.add(`${contactId}-ptt`);
    }

    circle.classList.add('animated');

    // Animate the progress circle
    const [progressLength, gapLength] = targetProgress.split(' ');

    // Use CSS animation for smooth progress
    progressPath.style.strokeDasharray = `0 100`;
    progressPath.style.transition = 'stroke-dasharray 0.8s cubic-bezier(0.25, 0.46, 0.45, 0.94)';

    setTimeout(() => {
      progressPath.style.strokeDasharray = targetProgress;
    }, 50);

    // Animate the text counter
    this.animateCounter(textElement, 0, targetScore, 800);
  },

  animateCounter(element, start, end, duration) {
    const startTime = performance.now();

    const updateCounter = (currentTime) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);

      // Use easing function for smooth animation
      const easedProgress = this.easeOutCubic(progress);
      const currentValue = start + (end - start) * easedProgress;

      element.textContent = currentValue.toFixed(1);

      if (progress < 1) {
        requestAnimationFrame(updateCounter);
      }
    };

    requestAnimationFrame(updateCounter);
  },

  easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
  }
};

// Single PTT Animation hook for contact details page
Hooks.PTTAnimation = {
  mounted() {
    // Small delay to ensure DOM is ready
    setTimeout(() => {
      const pttCircle = this.el.querySelector('.ptt-circle');
      if (pttCircle) {
        this.animatePTTCircle(pttCircle);
      }
    }, 200);
  },

  animatePTTCircle(circle) {
    const progressPath = circle.querySelector('.ptt-circle-progress');
    const textElement = circle.querySelector('.ptt-circle-text');
    const targetProgress = progressPath.getAttribute('data-target-progress');
    const targetScore = parseFloat(textElement.getAttribute('data-target-score'));

    // Animate the progress circle
    progressPath.style.strokeDasharray = `0 100`;
    progressPath.style.transition = 'stroke-dasharray 0.8s cubic-bezier(0.25, 0.46, 0.45, 0.94)';

    setTimeout(() => {
      progressPath.style.strokeDasharray = targetProgress;
    }, 50);

    // Animate the text counter
    this.animateCounter(textElement, 0, targetScore, 800);
  },

  animateCounter(element, start, end, duration) {
    const startTime = performance.now();

    const updateCounter = (currentTime) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);

      // Use easing function for smooth animation
      const easedProgress = this.easeOutCubic(progress);
      const currentValue = start + (end - start) * easedProgress;

      element.textContent = currentValue.toFixed(1);

      if (progress < 1) {
        requestAnimationFrame(updateCounter);
      } else {
        // Ensure final state
        element.style.color = '#6366f1';
      }
    };

    requestAnimationFrame(updateCounter);
  },

  easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
  }
};

// User dropdown hook
Hooks.UserDropdown = {
  mounted() {
    this.button = this.el.querySelector('#user-dropdown-button');
    this.menu = this.el.querySelector('#user-dropdown-menu');

    // Toggle dropdown on button click
    this.button.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.toggleDropdown();
    });

    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (!this.el.contains(e.target)) {
        this.closeDropdown();
      }
    });

    // Close dropdown on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.closeDropdown();
      }
    });
  },

  toggleDropdown() {
    this.menu.classList.toggle('show');
  },

  closeDropdown() {
    this.menu.classList.remove('show');
  },

  destroyed() {
    // Clean up event listeners
    document.removeEventListener('click', this.handleOutsideClick);
    document.removeEventListener('keydown', this.handleEscapeKey);
  }
};


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken
  },
  hooks: Hooks
});

// Show progress bar on live navigation and form submits
topbar.config({
  barColors: { 0: "#4836bf" },
  barThickness: 4,
  shadowBlur: 0,
  shadowColor: "transparent",
  className: "topbar"
});
window.addEventListener("phx:page-loading-start", _info => topbar.show(200));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

// Connect if there are any LiveViews on the page
liveSocket.connect();

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// Initialize PostHog analytics in production
// https://posthog.com/docs/libraries/js
if (window.location.host.includes("heywalt.ai")) {
  posthog.init(POSTHOG_API_KEY, { api_host: POSTHOG_API_URL });
}

// This listener is used to open the Stripe portal in a new tab.
window.addEventListener("phx:open-stripe-portal", (e) => {
  window.location = e.detail.url;
});
