import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-white dark:from-black dark:to-zinc-900">
      
      {/* NAVBAR */}
      <nav className="flex items-center justify-between px-8 py-5 bg-white/80 backdrop-blur-md border-b">
        <h1 className="text-2xl font-bold text-blue-700">AMEXAN</h1>

        <div className="flex gap-6 items-center">
          <Link href="/login" className="text-sm font-medium">
            Login
          </Link>
          <Link
            href="/register"
            className="bg-blue-600 text-white px-5 py-2 rounded-lg hover:bg-blue-700"
          >
            Get Started
          </Link>
        </div>
      </nav>

      {/* HERO SECTION */}
      <section className="max-w-7xl mx-auto px-6 py-24 grid md:grid-cols-2 gap-12 items-center">
        
        <div>
          <h1 className="text-5xl font-extrabold leading-tight text-zinc-900 dark:text-white">
            The Future of Healthcare  
            <span className="text-blue-600"> Starts Here</span>
          </h1>

          <p className="mt-6 text-lg text-zinc-600 dark:text-zinc-300">
            AMEXAN is your lifelong digital health partner — connecting patients,
            doctors, clinics, and disease management tools in one intelligent
            platform.
          </p>

          <div className="mt-8 flex gap-4">
            <Link
              href="/register"
              className="bg-blue-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-blue-700"
            >
              Join as Patient
            </Link>

            <Link
              href="/register?role=doctor"
              className="border px-6 py-3 rounded-xl font-semibold hover:bg-zinc-100 dark:hover:bg-zinc-800"
            >
              Join as Doctor
            </Link>
          </div>
        </div>

        {/* HERO CARD */}
        <div className="bg-white dark:bg-zinc-900 shadow-2xl rounded-3xl p-8 border">
          <h3 className="text-xl font-bold mb-4">
            Your Health Command Center
          </h3>

          <ul className="space-y-3 text-zinc-600 dark:text-zinc-300">
            <li>✔ Book verified doctors instantly</li>
            <li>✔ Manage chronic diseases</li>
            <li>✔ Secure medical history</li>
            <li>✔ Smart health ID & emergency profile</li>
            <li>✔ Real-time consultations</li>
          </ul>
        </div>
      </section>

      {/* FEATURES */}
      <section className="bg-white dark:bg-black py-20">
        <div className="max-w-6xl mx-auto px-6">
          
          <h2 className="text-3xl font-bold text-center mb-14">
            Why AMEXAN?
          </h2>

          <div className="grid md:grid-cols-3 gap-10">
            
            <Feature
              title="Smart Doctor Marketplace"
              text="Find specialists, compare services, and book instantly with full transparency."
            />

            <Feature
              title="Disease Management Engine"
              text="Personalized tools for diabetes, hypertension, asthma and more."
            />

            <Feature
              title="Lifelong Health Records"
              text="Your complete medical journey secured and accessible anywhere."
            />
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-24 text-center">
        <h2 className="text-4xl font-bold mb-6">
          Start Your Health Journey Today
        </h2>

        <Link
          href="/register"
          className="bg-blue-600 text-white px-8 py-4 rounded-2xl text-lg font-semibold hover:bg-blue-700"
        >
          Create Free Account
        </Link>
      </section>

      {/* FOOTER */}
      <footer className="text-center py-10 text-zinc-500 border-t">
        © {new Date().getFullYear()} AMEXAN — Lifelong Health Platform
      </footer>
    </div>
  );
}

// FEATURE COMPONENT
function Feature({ title, text }: { title: string; text: string }) {
  return (
    <div className="p-8 rounded-2xl shadow-lg border bg-zinc-50 dark:bg-zinc-900">
      <h3 className="text-xl font-bold mb-3">{title}</h3>
      <p className="text-zinc-600 dark:text-zinc-300">{text}</p>
    </div>
  );
}