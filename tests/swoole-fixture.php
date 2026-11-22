<?php

use Symfony\Component\HttpFoundation\Cookie;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\HttpKernelInterface;
use Symfony\Component\HttpKernel\TerminableInterface;

require_once dirname(__DIR__).'/vendor/autoload_runtime.php';

return static function () {
    return new class implements HttpKernelInterface, TerminableInterface {
        private int $requests = 0;
        private int $terminated = 0;

        public function handle(Request $request, int $type = self::MAIN_REQUEST, bool $catch = true): Response
        {
            ++$this->requests;

            if ($request->getPathInfo() === '/session') {
                // Exercise Symfony's actual session listener and native storage.
                $listener = new class(null, false, ['cookie_secure' => false]) extends \Symfony\Component\HttpKernel\EventListener\AbstractSessionListener {
                    protected function getSession(): ?\Symfony\Component\HttpFoundation\Session\SessionInterface
                    {
                        return new \Symfony\Component\HttpFoundation\Session\Session(
                            new \Symfony\Component\HttpFoundation\Session\Storage\NativeSessionStorage(['cookie_secure' => false]),
                        );
                    }
                };
                $listener->onKernelRequest(new \Symfony\Component\HttpKernel\Event\RequestEvent($this, $request, $type));
                $session = $request->getSession();
                $visits = $session->get('visits', 0) + 1;
                $session->set('visits', $visits);
                $response = new Response((string) $visits);
                $listener->onKernelResponse(new \Symfony\Component\HttpKernel\Event\ResponseEvent($this, $request, $type, $response));
                $listener->reset();

                return $response;
            }

            $response = new Response('PHP fallback', 200, [
                'Content-Type' => 'text/plain',
                'Cache-Control' => 'private, no-store',
                'X-Worker-Pid' => (string) getmypid(),
                'X-Worker-Requests' => (string) $this->requests,
                'X-Terminated' => (string) $this->terminated,
                'X-Request-Uri' => $request->getRequestUri(),
                'X-Client-Ip' => $request->getClientIp(),
                'X-Multi' => ['one', 'two'],
                'X-Scheme' => $request->getScheme(),
                'X-Request-Method' => $request->getMethod(),
                'X-Request-Body' => $request->getContent(),
            ]);
            $response->headers->setCookie(Cookie::create('first', '1'));
            $response->headers->setCookie(Cookie::create('second', '2'));

            return $response;
        }

        public function terminate(Request $request, Response $response): void
        {
            ++$this->terminated;
        }
    };
};
