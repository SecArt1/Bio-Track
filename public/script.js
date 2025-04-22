// filepath: c:\Users\rewmo\Dev\G.P\gp\public\script.js
document.addEventListener('DOMContentLoaded', function() {

    // --- FAQ Accordion ---
    const faqItems = document.querySelectorAll('.faq-item');
    faqItems.forEach(item => {
        const question = item.querySelector('.faq-question');
        if (question) {
            question.addEventListener('click', () => {
                const currentlyActive = document.querySelector('.faq-item.active');
                if (currentlyActive && currentlyActive !== item) {
                    currentlyActive.classList.remove('active');
                }
                item.classList.toggle('active');
            });
        }
    });

    // --- Active Nav Link ---
    // Get the current page path
    const currentPage = window.location.pathname;
    const navLinks = document.querySelectorAll('header nav ul li a');

    navLinks.forEach(link => {
        // Remove existing active class
        link.classList.remove('active');

        // Get the link's href attribute
        const linkPath = link.getAttribute('href');

        // Check if the link's path matches the current page path
        // Handle '/' specifically for the homepage
        if ((currentPage === '/' && linkPath === '/') || (linkPath !== '/' && currentPage.endsWith(linkPath))) {
            link.classList.add('active');
        }
    });

});