WSData = {
    _data_map_data: null,
    _student_data: null,
    _major_course_data: null,
    _status_data: null,
    _success_callbacks: {},
    _error_callbacks: {},
    _callback_args: {},



    _is_running_url: function(url) {
        if (WSData._success_callbacks[url] && WSData._success_callbacks[url].length) {
            return true;
        }
        return false;
    },
    _enqueue_callbacks_for_url: function(url, success, error, args) {
        if (!WSData._success_callbacks[url]) {
            WSData._success_callbacks[url] = [];
            WSData._error_callbacks[url] = [];
            WSData._callback_args[url] = [];
        }
        // Even if these are null, push them so the lists stay in sync.
        WSData._success_callbacks[url].push(success);
        WSData._error_callbacks[url].push(error);
        WSData._callback_args[url].push(args);
    },

    _run_success_callbacks_for_url: function(url) {
        var i,
            callback,
            args;

        for (i = 0; i < WSData._success_callbacks[url].length; i++) {
            callback = WSData._success_callbacks[url][i];
            args = WSData._callback_args[url][i];

            if (callback) {
                callback.apply(null, args);
            }
        }

        delete WSData._success_callbacks[url];
        delete WSData._error_callbacks[url];
        delete WSData._callback_args[url];
    },

    _run_error_callbacks_for_url: function(url) {
        var i,
            callback,
            args;

        for (i = 0; i < WSData._error_callbacks[url].length; i++) {
            callback = WSData._error_callbacks[url][i];
            args = WSData._callback_args[url][i];

            if (callback) {
                callback.apply(null, args);
            }
        }

        delete WSData._success_callbacks[url];
        delete WSData._error_callbacks[url];
        delete WSData._callback_args[url];
    },

    data_map_data: function() {
        return WSData._data_map_data;
    },

    student_data: function() {
        return WSData._student_data;
    },

    major_course_data: function() {
        return WSData._major_course_data;
    },

    status_data: function() {
        return WSData._status_data;
    },

    fetch_data_map_data: function(callback, err_callback, args) {
        if (WSData._data_map_data === null) {
            var url = "/api/v1/data_map/";

            if (WSData._is_running_url(url)) {
                WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
                return;
            }

            WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
            $.ajax({

                url: url,
                type: "GET",
                success: function(results) {
                    WSData._data_map_data = results;
                    WSData._run_success_callbacks_for_url(url);
                },
                error: function(xhr, status, error) {
                    WSData._run_error_callbacks_for_url(url);
                }
            });
        }
        else {
            window.setTimeout(function() {
                callback.apply(null, args);
            }, 0);
        }
    },

    fetch_student_data: function(callback, err_callback, args) {
        if (WSData._student_data === null) {
            var url = "/api/v1/student_data/";

            if (WSData._is_running_url(url)) {
                WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
                return;
            }

            WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
            $.ajax({

                url: url,
                type: "GET",
                success: function(results) {
                    WSData._student_data = results;
                    WSData._run_success_callbacks_for_url(url);
                },
                error: function(xhr, status, error) {
                    WSData._run_error_callbacks_for_url(url);
                }
            });
        }
        else {
            window.setTimeout(function() {
                callback.apply(null, args);
            }, 0);
        }
    },

    fetch_major_course_data: function(callback, err_callback, args) {
        if (WSData._major_course_data === null) {
            var url = "/api/v1/major_course/";

            if (WSData._is_running_url(url)) {
                WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
                return;
            }

            WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
            $.ajax({

                url: url,
                type: "GET",
                success: function(results) {
                    WSData._major_course_data = results;
                    WSData._run_success_callbacks_for_url(url);
                },
                error: function(xhr, status, error) {
                    WSData._run_error_callbacks_for_url(url);
                }
            });
        }
        else {
            window.setTimeout(function() {
                callback.apply(null, args);
            }, 0);
        }
    },

    fetch_status_data: function(callback, err_callback, args) {
        if (WSData._status_data === null) {
            var url = "/api/v1/status_lookup/";

            if (WSData._is_running_url(url)) {
                WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
                return;
            }

            WSData._enqueue_callbacks_for_url(url, callback, err_callback, args);
            $.ajax({

                url: url,
                type: "GET",
                success: function(results) {
                    WSData._status_data = results;
                    WSData._run_success_callbacks_for_url(url);
                },
                error: function(xhr, status, error) {
                    WSData._run_error_callbacks_for_url(url);
                }
            });
        }
        else {
            window.setTimeout(function() {
                callback.apply(null, args);
            }, 0);
        }
    }
};
