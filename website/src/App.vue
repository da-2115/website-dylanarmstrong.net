<script setup>
const navLinks = [
  { label: 'Home', href: '#home' },
  { label: 'Projects', href: '#projects' },
  { label: 'Skills', href: '#skills' },
  { label: 'About', href: '#about' },
  { label: 'Contact', href: '#contact' }
]

const projects = [
  {
    title: 'The T# Programming Language',
    link: 'https://github.com/da-2115/tsharp',
    description:
      'An object-oriented and procedural language written in C++ with the ANTLR framework, which is turing complete.',
    tags: ['C++', 'ANTLR', 'CMake']
  },
  {
    title: 'dylanarmstrong.net',
    link: '#',
    description: 'My website.',
    tags: ['Vue.js', 'Node.js', 'TailwindCSS']
  },
  {
    title: 'T# Language Documentation Website',
    link: 'https://tsharp.dylanarmstrong.net/',
    description:
      'The official website for T# documentation and syntax guidance with examples.',
    tags: ['Vue.js', 'Node.js', 'TailwindCSS']
  }
]

const skillGroups = [
  {
    title: 'Software Engineering',
    items: [
      'Web Development',
      'Data Structures and Algorithms',
      'Object-Oriented Programming',
      'Programming Language Design and Implementation',
      'Concurrent Programming'
    ]
  },
  {
    title: 'Machine Learning',
    items: [
      'Federated Machine Learning',
      'Supervised/Unsupervised Learning',
      'Linear Algebra',
      'Python'
    ]
  },
  {
    title: 'DevOps',
    items: ['Git', 'PowerShell', 'Terraform', 'Docker', 'Bash']
  }
]

const stats = [
  { value: '10+', label: 'Projects' },
  { value: '5+', label: 'Years Experience' },
  { value: '100%', label: 'Satisfaction' }
]

const socialLinks = [
  { label: 'GH', href: 'https://github.com/da-2115' },
  { label: 'IN', href: 'https://www.linkedin.com/in/dylan-armstrong-b12321220/' },
  { label: '✉', href: 'mailto:dylan.armstrong2@protonmail.com' }
]

function scrollToSection(id) {
  const section = document.querySelector(id)
  if (section) {
    section.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}
</script>

<template>
  <div class="min-h-screen text-slate-100">
    <header class="sticky top-0 z-30 border-b border-white/10 bg-[#050812]/70 backdrop-blur-xl">
      <div class="mx-auto flex w-full max-w-6xl flex-wrap items-center justify-between gap-2 px-5 py-4 md:px-8">
        <div class="text-base font-bold tracking-wide">Dylan Armstrong</div>
        <nav class="flex flex-wrap gap-4 text-sm text-slate-300" aria-label="Primary">
        <a v-for="link in navLinks" :key="link.label" :href="link.href">{{ link.label }}</a>
        </nav>
      </div>
    </header>

    <main>
      <section id="home" class="mx-auto w-full max-w-6xl px-5 pb-16 pt-24 text-center md:px-8 md:pb-20 md:pt-28">
        <h1 class="mx-auto max-w-4xl text-4xl font-semibold leading-tight md:text-6xl">
          Software Engineer
        </h1>
        <p class="mx-auto mt-4 max-w-2xl text-base text-slate-300 md:text-lg">
          Creating beautiful, functional web experiences with modern technologies
        </p>
        <div class="mt-8 flex flex-wrap justify-center gap-3">
          <button
            type="button"
            class="rounded-full bg-gradient-to-r from-sky-400 to-emerald-300 px-5 py-3 font-semibold text-white transition hover:-translate-y-0.5"
            @click="scrollToSection('#projects')"
          >
            View My Work
          </button>
          <button
            type="button"
            class="rounded-full border border-white/20 px-5 py-3 font-semibold text-slate-100 transition hover:bg-white/5"
            @click="scrollToSection('#contact')"
          >
            Get In Touch
          </button>
        </div>
      </section>

      <section id="projects" class="mx-auto w-full max-w-6xl px-5 pt-16 md:px-8 md:pt-20">
        <div>
          <h2 class="text-3xl font-semibold md:text-4xl">Featured Projects</h2>
          <p class="mt-2 text-slate-300">Some of my recent work and passion projects</p>
        </div>

        <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <article
            v-for="project in projects"
            :key="project.title"
            class="rounded-2xl border border-white/10 bg-[#121936cc] p-5 shadow-[0_10px_30px_rgba(0,0,0,0.2)]"
          >
            <div class="flex items-center justify-between gap-2">
              <h3 class="text-lg font-semibold">{{ project.title }}</h3>
              <a
                :href="project.link"
                target="_blank"
                rel="noreferrer"
                class="inline-flex h-8 w-8 items-center justify-center rounded-full border border-white/20"
                >→</a
              >
            </div>
            <p class="mt-3 min-h-14 text-slate-300">{{ project.description }}</p>
            <ul class="mt-3 flex list-none flex-wrap gap-2 p-0" aria-label="Project technologies">
              <li
                v-for="tag in project.tags"
                :key="`${project.title}-${tag}`"
                class="rounded-full border border-sky-300/25 px-2.5 py-1 text-xs text-sky-100"
              >
                {{ tag }}
              </li>
            </ul>
          </article>
        </div>
      </section>

      <section id="skills" class="mx-auto w-full max-w-6xl px-5 pt-16 md:px-8 md:pt-20">
        <div>
          <h2 class="text-3xl font-semibold md:text-4xl">Skills &amp; Expertise</h2>
          <p class="mt-2 text-slate-300">Technologies and tools I work with</p>
        </div>

        <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <article
            v-for="group in skillGroups"
            :key="group.title"
            class="rounded-2xl border border-white/10 bg-[#121936cc] p-5 shadow-[0_10px_30px_rgba(0,0,0,0.2)]"
          >
            <h3 class="text-lg font-semibold">{{ group.title }}</h3>
            <ul class="mt-3 list-disc pl-5 text-slate-300">
              <li v-for="item in group.items" :key="`${group.title}-${item}`">{{ item }}</li>
            </ul>
          </article>
        </div>
      </section>

      <section id="about" class="mx-auto grid w-full max-w-6xl gap-5 px-5 pt-16 md:grid-cols-[1.1fr,0.9fr] md:px-8 md:pt-20">
        <div>
          <h2 class="text-3xl font-semibold md:text-4xl">About Me</h2>
          <p class="mt-3 text-slate-300">
            I'm a software engineer with a love for learning and
            creating solutions to complex problems. With prior experience in the industry, I can apply
            my skills to advanced software problems.
          </p>
          <p class="mt-4 text-slate-300">
            When I'm not coding, you'll find me exploring new technologies,
            building things and improving my skills.
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-3 md:grid-cols-3" aria-label="Career highlights">
          <article
            v-for="item in stats"
            :key="item.label"
            class="rounded-2xl border border-white/10 bg-[#1a2448] p-4 text-center"
          >
            <div class="text-2xl font-semibold">{{ item.value }}</div>
            <div class="text-sm text-slate-300">{{ item.label }}</div>
          </article>
        </div>
      </section>

      <section id="contact" class="mx-auto w-full max-w-6xl px-5 pb-6 pt-16 text-center md:px-8 md:pt-20">
        <h2 class="text-3xl font-semibold md:text-4xl">Let's Connect</h2>
        <p class="mt-2 text-slate-300">Feel free to reach out for collaborations or just a friendly hello</p>
        <a
          class="mt-4 inline-block rounded-xl border border-white/15 bg-[#0f1838] px-4 py-3 font-semibold"
          href="mailto:dylan.armstrong2@protonmail.com"
        >
          ✉ dylan.armstrong2@protonmail.com
        </a>

        <div class="mt-4 flex justify-center gap-3">
          <a
            v-for="social in socialLinks"
            :key="social.label"
            :href="social.href"
            target="_blank"
            rel="noreferrer"
            class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-white/20 text-slate-300"
          >
            {{ social.label }}
          </a>
        </div>
      </section>
    </main>

    <footer class="mt-7 border-t border-white/10 bg-[#060a19]">
      <div class="mx-auto flex min-h-10 w-full max-w-6xl items-center justify-center px-5 text-sm text-slate-300 md:px-8">
        <span>© 2026 Dylan Armstrong.</span>
      </div>
    </footer>
  </div>
</template>