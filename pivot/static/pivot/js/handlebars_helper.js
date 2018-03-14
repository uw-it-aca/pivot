// Helper function allows us to perfom equality logic within a handlebar template
Handlebars.registerHelper('ifEquals', function(a, b, options) {
  if (a === b) {
    return options.fn(this)
  }
  return options.inverse(this)
});
