// Feedback form js

// $("#compare-msg").html('<div class="alert alert-danger">Please enter a valid GPA between 1.5 and 4.0</div>');

// feedbackForm
$("#feedbackForm").submit((event) => {
    // Stop the browser from submitting the form.
    event.preventDefault();
    let formData = $("#feedbackForm").serialize();

    formData += "&_cc=lyle3@uw.edu";
    // Compile the feedback template
    const source = $("#feedback").html();
    const template = Handlebars.compile(source);

    $.ajax({
        type: 'POST',
        url: 'https://formspree.io/abievans@uw.edu', // $("#feedbackForm").attr('action'),
        data: formData,
        dataType: "json"
    }).done((response) => {
        $("#senderEmail").val('');
        $("#message").val('');
        $("#returnMessage").html(template({
            message_type: "alert-success",
            message: "Message sent!"
        }));
    }).fail((data) => {
        $("#returnMessage").html(template({
            message_type: "alert-danger",
            message: "Message could not be sent! Please email lyle3@uw.edu directly."
        }));
    });
});
