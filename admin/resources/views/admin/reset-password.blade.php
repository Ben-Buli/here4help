<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <link rel="icon" href="/admin/public/H4H.ico" type="image/x-icon">
    <title>Admin Password Reset | Here4Help</title>
    <style>
        :root {
            --primary: #0f172a;
            --accent: #2563eb;
            --gray-100: #f1f5f9;
            --gray-300: #cbd5f5;
            --gray-500: #64748b;
            --gray-700: #1e293b;
            --danger: #dc2626;
            --success: #15803d;
        }

        * {
            box-sizing: border-box;
        }

        body {
            font-family: "Inter", system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(180deg, #e0f2fe 0%, #f8fafc 100%);
            padding: 32px 16px;
        }

        .card {
            width: 100%;
            max-width: 520px;
            background: #fff;
            border-radius: 28px;
            padding: 36px;
            box-shadow: 0 30px 60px rgba(15, 23, 42, 0.15);
        }

        .brand {
            display: flex;
            justify-content: center;
            margin-bottom: 18px;
        }

        .brand img {
            width: 56px;
            height: 56px;
            border-radius: 18px;
            box-shadow: 0 10px 25px rgba(15, 23, 42, 0.15);
        }

        h1 {
            font-size: 1.75rem;
            margin: 0;
            color: var(--gray-700);
        }

        p.description {
            color: var(--gray-500);
            line-height: 1.6;
            margin-top: 8px;
            margin-bottom: 0;
        }

        .badge {
            margin-top: 16px;
            font-weight: 600;
            color: var(--gray-700);
        }

        label {
            display: block;
            font-weight: 600;
            margin-bottom: 8px;
            margin-top: 18px;
            color: var(--gray-700);
        }

        .input-wrapper {
            position: relative;
        }

        input[type="password"],
        input[type="text"] {
            width: 100%;
            border-radius: 14px;
            border: 1px solid var(--gray-300);
            padding: 14px 46px 14px 14px;
            font-size: 1rem;
            transition: border-color 0.2s, box-shadow 0.2s;
        }

        input:focus {
            outline: none;
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.25);
        }

        .toggle-visibility {
            position: absolute;
            right: 12px;
            top: 50%;
            transform: translateY(-50%);
            border: none;
            background: transparent;
            color: var(--gray-500);
            cursor: pointer;
            width: 36px;
            height: 36px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: color 0.2s, background 0.2s;
        }

        .toggle-visibility svg {
            width: 20px;
            height: 20px;
        }

        .toggle-visibility:hover,
        .toggle-visibility.active {
            color: #0ea5e9;
            background: rgba(14, 165, 233, 0.1);
        }

        .requirements {
            margin-top: 18px;
            padding: 14px;
            border-radius: 14px;
            background: var(--gray-100);
            color: var(--gray-500);
            font-size: 0.9rem;
            list-style: none;
        }

        .requirements li {
            margin-bottom: 6px;
        }

        .requirements li.met {
            color: var(--success);
            font-weight: 600;
        }

        .status {
            margin-top: 20px;
            border-radius: 14px;
            padding: 12px 14px;
            display: none;
            font-size: 0.95rem;
        }

        .status.error {
            display: block;
            background: #fee2e2;
            color: var(--danger);
            border: 1px solid #fecaca;
        }

        .status.success {
            display: block;
            background: #dcfce7;
            color: var(--success);
            border: 1px solid #bbf7d0;
        }

        button[type="submit"] {
            margin-top: 24px;
            width: 100%;
            border: none;
            border-radius: 14px;
            padding: 14px;
            background: linear-gradient(90deg, var(--accent), #0ea5e9);
            color: #fff;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: opacity 0.2s;
        }

        button[disabled] {
            opacity: 0.6;
            cursor: not-allowed;
        }

		.strength-indicator {
		    margin-top: 20px;
		    padding: 12px 14px;
		    border-radius: 18px;
		    background: #fff8ed;
		    border: 1px solid #fed7aa;
		    transition: background 0.2s, border-color 0.2s;
		}

		.strength-indicator.weak {
		    background: #fff3e6;
		    border-color: #fda57d;
		}

		.strength-indicator.medium {
		    background: #fffbe6;
		    border-color: #facc15;
		}

		.strength-indicator.strong {
		    background: #ecfdf5;
		    border-color: #34d399;
		}

		.strength-status {
		    font-size: 0.9rem;
		    color: #c2410c;
		    font-weight: 600;
		    display: flex;
		    align-items: center;
		    gap: 6px;
		    margin-bottom: 8px;
		    transition: color 0.2s;
		}

        .strength-status.medium {
            color: #ca8a04;
        }

        .strength-status.strong {
            color: #15803d;
        }

		.strength-value {
		    font-weight: 700;
		    color: #fb923c;
		    transition: color 0.2s;
		}

		.strength-value.medium {
		    color: #facc15;
		}

		.strength-value.strong {
		    color: #16a34a;
		}

        .strength-bars {
            margin-top: 10px;
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 6px;
        }

        .strength-bar {
            height: 6px;
            border-radius: 999px;
            background: #fed7aa;
            transition: background 0.2s;
        }

        .strength-bar.active-weak {
            background: linear-gradient(90deg, #fb923c, #f97316);
        }

        .strength-bar.active-medium {
            background: linear-gradient(90deg, #f97316, #facc15);
        }

        .strength-bar.active-strong {
            background: linear-gradient(90deg, #facc15, #34d399);
        }

        .helper-text {
            margin-top: 18px;
            font-size: 0.9rem;
            color: var(--gray-500);
        }

        .helper-text a {
            color: var(--accent);
            text-decoration: none;
        }

        @media (max-width: 480px) {
            .card {
                padding: 26px;
            }
        }
    </style>
</head>

<body>
    <main class="card">
        <div class="brand">
            <img src="/admin/public/H4H.ico" alt="Here4Help" />
        </div>
        <h1>Reset your admin password</h1>
        <p class="description">Enter a new password for your Here4Help admin panel account. This secure link expires one hour after it was issued.</p>
        <!-- <p class="description">Reset password for:</p> -->
        <p id="emailBadge" class="badge"></p>
        <hr>
        <div id="status" class="status"></div>

        <form id="resetForm" novalidate>
            <label for="newPassword">New password</label>
            <div class="input-wrapper">
                <input type="password" id="newPassword" placeholder="Enter a new password" autocomplete="new-password" maxlength="255" required>
                <button type="button" class="toggle-visibility" data-target="newPassword" aria-label="Toggle password visibility">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z" />
                        <circle cx="12" cy="12" r="3.5" />
                    </svg>
                </button>
            </div>

            <label for="confirmPassword">Confirm new password</label>
            <div class="input-wrapper">
                <input type="password" id="confirmPassword" placeholder="Re-enter your password" autocomplete="new-password" maxlength="255" required>
                <button type="button" class="toggle-visibility" data-target="confirmPassword" aria-label="Toggle password visibility">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z" />
                        <circle cx="12" cy="12" r="3.5" />
                    </svg>
                </button>
            </div>

            <ul class="requirements" id="requirements">
                <li data-rule="length">At least 6 characters</li>
                <li data-rule="allowed">Only letters, numbers, or English punctuation (no spaces)</li>
            </ul>

            <div class="strength-indicator weak" id="strengthBox">
                <div class="strength-status weak" id="strengthStatus">Strength：<span id="strengthLabel" class="strength-value weak">Weak</span></div>
                <div class="strength-bars">
                    <span class="strength-bar" data-level="weak"></span>
                    <span class="strength-bar" data-level="medium"></span>
                    <span class="strength-bar" data-level="strong"></span>
                </div>
            </div>

            <button type="submit" id="submitButton">Reset Password</button>
        </form>

        <!-- <p class="helper-text">
            Need help? Contact <a href="mailto:support@here4help.com">support@here4help.com</a>.
        </p> -->
    </main>

    <script>
        (function () {
            const form = document.getElementById('resetForm')
            const statusEl = document.getElementById('status')
            const newPasswordInput = document.getElementById('newPassword')
            const confirmPasswordInput = document.getElementById('confirmPassword')
            const requirementItems = document.querySelectorAll('#requirements [data-rule]')
            const submitButton = document.getElementById('submitButton')
            const emailBadge = document.getElementById('emailBadge')
            const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content')
            const strengthLabel = document.getElementById('strengthLabel')
            const strengthBox = document.getElementById('strengthBox')
            const strengthStatus = document.getElementById('strengthStatus')
            const strengthBars = document.querySelectorAll('.strength-bar')
            const allowedRegex = /^[A-Za-z0-9!"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~]+$/

            const params = new URLSearchParams(window.location.search)
            const token = params.get('token')
            const email = params.get('email')

            const setStatus = (message, variant = 'error') => {
                statusEl.textContent = message
                statusEl.className = `status ${variant}`
            }

            if (!token || !email) {
                setStatus('This link is invalid. Please request a new password reset link from the system administrator.')
                form.querySelectorAll('input, button').forEach((el) => el.setAttribute('disabled', 'disabled'))
                return
            }

            emailBadge.textContent = `${email}`

            document.querySelectorAll('.toggle-visibility').forEach((btn) => {
                btn.addEventListener('click', () => {
                    const targetId = btn.getAttribute('data-target')
                    const input = document.getElementById(targetId)
                    if (input.type === 'password') {
                        input.type = 'text'
                        btn.classList.add('active')
                    } else {
                        input.type = 'password'
                        btn.classList.remove('active')
                    }
                })
            })

            const updateStrengthIndicator = () => {
                const value = newPasswordInput.value
                let score = 0
                if (value.length >= 7) score++
                if (value.length >= 10) score++
                const variety = [/[A-Z]/, /[a-z]/, /\d/, /[!"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~]/].reduce((acc, regex) => acc + (regex.test(value) ? 1 : 0), 0)
                if (variety >= 2) score++
                if (variety >= 3) score++

                const level = score >= 4 ? 'strong' : score >= 2 ? 'medium' : 'weak'
                const labels = { weak: 'Weak', medium: 'Medium', strong: 'Strong' }
                strengthLabel.textContent = labels[level]
                strengthLabel.className = `strength-value ${level}`
                strengthBox.className = `strength-indicator ${level}`
                strengthStatus.className = `strength-status ${level}`

                strengthBars.forEach((bar) => {
                    bar.classList.remove('active-weak', 'active-medium', 'active-strong')
                    const barLevel = bar.getAttribute('data-level')
                    if (level === 'weak' && barLevel === 'weak') {
                        bar.classList.add('active-weak')
                    }
                    if (level === 'medium' && (barLevel === 'weak' || barLevel === 'medium')) {
                        bar.classList.add(barLevel === 'weak' ? 'active-weak' : 'active-medium')
                    }
                    if (level === 'strong') {
                        if (barLevel === 'weak') bar.classList.add('active-weak')
                        if (barLevel === 'medium') bar.classList.add('active-medium')
                        if (barLevel === 'strong') bar.classList.add('active-strong')
                    }
                })
            }

            const updateRequirements = () => {
                const value = newPasswordInput.value
                const tests = {
                    length: value.length >= 6 && value.length <= 255,
                    allowed: value.length > 0 && allowedRegex.test(value),
                }

                requirementItems.forEach((item) => {
                    const rule = item.getAttribute('data-rule')
                    item.classList.toggle('met', !!tests[rule])
                })

                updateStrengthIndicator()
                return Object.values(tests).every(Boolean)
            }

            newPasswordInput.addEventListener('input', updateRequirements)

            form.addEventListener('submit', async (event) => {
                event.preventDefault()
                statusEl.className = 'status'

                const meetsRules = updateRequirements()
                if (!meetsRules) {
                    setStatus('Please meet all password rules before submitting.')
                    return
                }

                if (newPasswordInput.value !== confirmPasswordInput.value) {
                    setStatus('Passwords do not match. Please try again.')
                    return
                }

                submitButton.disabled = true
                submitButton.textContent = 'Resetting…'

                try {
                    const response = await fetch("{{ route('admin.password.reset.submit') }}", {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'X-CSRF-TOKEN': csrfToken,
                            'Accept': 'application/json'
                        },
                        body: JSON.stringify({
                            token,
                            email,
                            new_password: newPasswordInput.value,
                            confirm_password: confirmPasswordInput.value,
                        }),
                    })

                    const result = await response.json()

                    if (!response.ok || !result.success) {
                        throw new Error(result.message || 'Unable to reset password.')
                    }

                    setStatus(result.message || 'Password reset successfully.', 'success')
                    form.querySelectorAll('input, button').forEach((el) => el.setAttribute('disabled', 'disabled'))
                } catch (error) {
                    setStatus(error.message || 'Unexpected error. Please try again.')
                    submitButton.disabled = false
                    submitButton.textContent = 'Reset Password'
                }
            })

            updateRequirements()
        })()
    </script>
</body>

</html>
